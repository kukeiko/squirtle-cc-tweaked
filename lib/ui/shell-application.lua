local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ShellWindow = require "lib.ui.shell-window"

---@class ShellApplication
---@field metadata Application
---@field window table
---@field windowIndex integer
---@field windows ShellWindow[]
---@field addWindowToShell fun(window: ShellWindow) : nil
---@field runSelf fun() : nil
---@field drawMenu fun() : nil
---@field launchApp fun(path: string) : nil
local ShellApplication = {}

---@param metadata Application
---@param window table
---@param runSelf fun() : nil
---@return ShellApplication
function ShellApplication.new(metadata, window, runSelf)
    ---@type ShellApplication
    local instance = {
        metadata = metadata,
        window = window,
        windows = {},
        windowIndex = 1,
        addWindowToShell = function()
        end,
        runSelf = runSelf,
        launchApp = function()
        end,
        drawMenu = function()
        end
    }
    setmetatable(instance, {__index = ShellApplication})

    return instance
end

---@param title string
---@param fn fun(shellWindow: ShellWindow): any
function ShellApplication:addWindow(title, fn)
    local w, h = self.window.getSize()
    ---@type ShellWindow
    local shellWindow = ShellWindow.new(title, fn, window.create(self.window, 1, 1, w, h, false))
    table.insert(self.windows, shellWindow)
    self.addWindowToShell(shellWindow)
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
    end

    self.windowIndex = index
    self:showActiveWindow()
end

function ShellApplication:showActiveWindow()
    self.windows[self.windowIndex]:setVisible(true)
    EventLoop.queue("shell-window:visible", self.windows[self.windowIndex]:getId())
    self.drawMenu()
end

---@param path string
function ShellApplication:launch(path)
    self.launchApp(path)
end

function ShellApplication:run()
    self.runSelf()
end

return ShellApplication
