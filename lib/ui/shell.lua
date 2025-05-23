if _ENV["Shell"] then
    return _ENV["Shell"] --[[@as Shell]]
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@class ShellWindow
---@field title string
---@field fn fun(window: ShellWindow): any
---@field window table
local ShellWindow = {}

---@param title string
---@param fn fun(): any
---@param window table
---@return ShellWindow
function ShellWindow.new(title, fn, window)
    ---@type ShellWindow|{}
    local instance = {title = title, fn = fn, window = window}
    setmetatable(instance, {__index = ShellWindow})

    return instance
end

---@return boolean
function ShellWindow:isVisible()
    return self.window.isVisible()
end

---@class Shell
---@field window table
---@field windows ShellWindow[]
---@field activeWindow? ShellWindow
local Shell = {}

---@type fun(...: function)
local addThreadToEventLoop
local isRunning = false

local function new()
    local width, height = term.getSize()
    ---@type Shell | {}
    local instance = {window = window.create(term.current(), 1, 1, width, height, false), windows = {}}
    setmetatable(instance, {__index = Shell})

    return instance
end

---@param window table
---@param left? string
---@param right? string
local function drawNavBar(window, left, right)
    local width, height = window.getSize()
    window.setCursorPos(1, height - 1)
    window.write(string.rep("-", width))
    window.setCursorPos(1, height)
    window.clearLine()

    if left then
        window.setCursorPos(1, height)
        window.write(left)
    end

    if right then
        window.setCursorPos(width - #right, height)
        window.write(right)
    end
end

---@param self Shell
local function drawMenu(self)
    local activeWindowIndex = Utils.indexOf(self.windows, self.activeWindow)
    local leftTitle = activeWindowIndex > 1 and string.format("< %s", self.windows[activeWindowIndex - 1].title) or nil
    local rightTitle = activeWindowIndex < #self.windows and string.format("%s >", self.windows[activeWindowIndex + 1].title) or nil

    drawNavBar(self.window, leftTitle, rightTitle)
end

---@param event string
---@return boolean
local function isUiEvent(event)
    return event == "char" or event == "key" or event == "key_up" or event == "paste"
end

---@param event string
local function isShellWindowEvent(event)
    return Utils.startsWith(event, "shell-window")
end

---@param self Shell
---@param shellWindow ShellWindow
---@return function
local function createRunnableFromWindow(self, shellWindow)
    return function()
        EventLoop.configure({
            window = shellWindow.window,
            accept = function(event, ...)
                local args = {...}

                if isUiEvent(event) then
                    return self.activeWindow == shellWindow
                elseif isShellWindowEvent(event) then
                    return args[1] == shellWindow
                end

                return true
            end
        })

        -- [todo] this is needed, but investigate exactly why
        os.sleep(.1)

        if self.activeWindow == shellWindow then
            EventLoop.queue("shell-window:visible", shellWindow)
        end

        shellWindow.fn(shellWindow)

        -- [note] this hack is needed in case the UI event was responsible for terminating the window,
        -- at which point the next window is the active one and also receives the UI event (i.e. it "bleeds" over)
        os.sleep(.1)
        shellWindow.window.clear()
        local index = Utils.indexOf(self.windows, shellWindow)
        table.remove(self.windows, index)

        if index > #self.windows then
            index = #self.windows
        end

        if index > 0 then
            self.activeWindow = self.windows[index]
            self.activeWindow.window.setVisible(true)
            drawMenu(self)
        else
            self.activeWindow = nil
        end
    end
end

---@param title string
---@param fn fun(shellWindow: ShellWindow): any
function Shell:addWindow(title, fn)
    local w, h = self.window.getSize()

    ---@type ShellWindow
    local shellWindow = ShellWindow.new(title, fn, window.create(self.window, 1, 1, w, h - 2, false))
    table.insert(self.windows, shellWindow)

    if isRunning then
        addThreadToEventLoop(createRunnableFromWindow(self, shellWindow))
        drawMenu(self)
    end
end

function Shell:run()
    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.window.setVisible(true)

    local addThread, run = EventLoop.createRun(table.unpack(Utils.map(self.windows, function(shellWindow)
        return createRunnableFromWindow(self, shellWindow)
    end)))

    addThreadToEventLoop = addThread
    isRunning = true

    if self.windows[1] then
        self.activeWindow = self.windows[1]
        self.windows[1].window.setVisible(true)
    end

    EventLoop.waitForAny(function()
        run()
    end, function()
        drawMenu(self)

        while true do
            local key = EventLoop.pullKeys({keys.left, keys.right})
            local activeWindowIndex = Utils.indexOf(self.windows, self.activeWindow)

            if key == keys.left then
                activeWindowIndex = math.max(1, activeWindowIndex - 1)
            else
                activeWindowIndex = math.min(#self.windows, activeWindowIndex + 1)
            end

            if self.activeWindow ~= self.windows[activeWindowIndex] then
                self.activeWindow.window.setVisible(false)
                self.activeWindow = self.windows[activeWindowIndex]
                self.activeWindow.window.setVisible(true)
                drawMenu(self)
                EventLoop.queue("shell-window:visible", self.activeWindow)
            end
        end
    end)
    isRunning = false
    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.window.setVisible(false)
end

return new()
