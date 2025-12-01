local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ShellWindow = require "lib.system.shell-window"
local nextId = require "lib.tools.next-id"

---@class ShellApplication
---@field id number
---@field metadata Application
---@field window table
---@field windowIndex integer
---@field windows ShellWindow[]
---@field addThreadFn fun(...) : nil
---@field runLoopFn fun() : nil
---@field shell Shell
local ShellApplication = {}

---@param metadata Application
---@param window table
---@param shell Shell
---@return ShellApplication
function ShellApplication.new(metadata, window, shell)
    local addThreadFn, runLoopFn = EventLoop.createRun()

    ---@type ShellApplication
    local instance = {
        id = nextId(),
        metadata = metadata,
        window = window,
        windows = {},
        windowIndex = 1,
        addThreadFn = addThreadFn,
        runLoopFn = runLoopFn,
        shell = shell
    }
    setmetatable(instance, {__index = ShellApplication})

    return instance
end

---@return integer
function ShellApplication:getId()
    return self.id
end

---@param fn function
function ShellApplication:addThread(fn)
    self.addThreadFn(fn)
end

---@param title string
---@param fn fun(shellWindow: ShellWindow): any
function ShellApplication:addWindow(title, fn)
    local w, h = self.window.getSize()
    ---@type ShellWindow
    local shellWindow = ShellWindow.new(title, fn, window.create(self.window, 1, 1, w, h - 2, false))
    table.insert(self.windows, shellWindow)

    if #self.windows == 1 then
        shellWindow.window.setVisible(true)
        self.windowIndex = 1
    end

    local wrapper = function()
        EventLoop.configure({
            window = shellWindow.window,
            accept = function(event, ...)
                local args = {...}

                if self.shell:isUiEvent(event) then
                    return shellWindow == self.windows[self.windowIndex]
                elseif self.shell:isShellWindowEvent(event) then
                    return args[1] == shellWindow:getId()
                end

                return true
            end
        })
        os.sleep(.1)

        if shellWindow == self.windows[self.windowIndex] then
            EventLoop.queue("shell-window:visible", shellWindow:getId())
        end

        local success, message = pcall(shellWindow.fn, shellWindow)

        -- [note] this hack is needed in case an UI event was responsible for terminating the window,
        -- at which point the next window is the active one and also receives the UI event (i.e. it "bleeds" over)
        -- [todo] ❌ try to replicate to see if this is still an issue
        -- [todo] ❓ figure out if this is also needed for the wrapper in Shell:runApplication
        os.sleep(.1)

        if not success then
            shellWindow.window.clear()
            shellWindow.window.setCursorPos(1, 1)
            print(string.format("%s crashed", shellWindow.title))
            print(message)
            Utils.waitForUserToHitEnter("<hit enter to continue>")
        end

        shellWindow.window.clear()
        self:removeWindow(shellWindow)
    end

    self.addThreadFn(wrapper)
end

---@param shellWindow ShellWindow
function ShellApplication:removeWindow(shellWindow)
    local removedIndex = Utils.indexOf(self.windows, shellWindow)

    if removedIndex == nil then
        error("shell window not found")
    end

    table.remove(self.windows, removedIndex)

    if #self.windows == 0 then
        self.windowIndex = 0
    else
        if removedIndex < self.windowIndex then
            self.windowIndex = self.windowIndex - 1
        elseif self.windowIndex > #self.windows then
            self.windowIndex = #self.windows
        end

        self:showActiveWindow()
    end
end

---@param index integer
function ShellApplication:switchToWindowIndex(index)
    if self.windows[self.windowIndex] then
        self.windows[self.windowIndex]:setVisible(false)
        EventLoop.queue("shell-window:invisible", self.windows[self.windowIndex]:getId())
    end

    self.windowIndex = index
    self:showActiveWindow()
end

function ShellApplication:drawMenu()
    local index = self.windowIndex
    local left = index > 1 and string.format("< %s", self.windows[index - 1].title) or nil
    local right = index < #self.windows and string.format("%s >", self.windows[index + 1].title) or nil
    local width, height = self.window.getSize()
    self.window.setCursorPos(1, height - 1)
    self.window.write(string.rep("-", width))
    self.window.setCursorPos(1, height)
    self.window.clearLine()

    if left then
        self.window.setCursorPos(1, height)
        self.window.write(left)
    end

    if right then
        self.window.setCursorPos(width - #right, height)
        self.window.write(right)
    end
end

function ShellApplication:showActiveWindow()
    if not self.windows[self.windowIndex] then
        return
    end

    self.windows[self.windowIndex]:setVisible(true)
    EventLoop.queue("shell-window:visible", self.windows[self.windowIndex]:getId())
    self:drawMenu()
end

---@param name string
function ShellApplication:launch(name)
    self.shell:launch(self, name)
end

---@param name string
function ShellApplication:terminate(name)
    self.shell:terminate(self, name)
end

function ShellApplication:run()
    self:drawMenu()

    EventLoop.run(function()
        self.shell:run(self, self.runLoopFn)
    end, function()
        while true do
            local key = EventLoop.pullKeys({keys.left, keys.right})
            local nextIndex = self.windowIndex

            if key == keys.left then
                nextIndex = math.max(1, nextIndex - 1)
            else
                nextIndex = math.min(#self.windows, nextIndex + 1)
            end

            if nextIndex ~= self.windowIndex then
                self:switchToWindowIndex(nextIndex)
            end
        end
    end)

    term.clear()
    term.setCursorPos(1, 1)
end

---@param name string
---@return boolean
function ShellApplication:isRunning(name)
    return self.shell:isRunning(name)
end

function ShellApplication:pullApplicationStateChange()
    return self.shell:pullApplicationStateChange()
end

return ShellApplication
