local ShellWindow = require "lib.ui.shell-window"

---@class ShellApplication
---@field metadata Application
---@field window table
---@field windowIndex integer
---@field windows ShellWindow[]
---@field addWindowToShell fun(window: ShellWindow) : nil
---@field runSelf fun() : nil
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

---@param path string
function ShellApplication:launch(path)
    self.launchApp(path)
end

function ShellApplication:run()
    self.runSelf()
end

return ShellApplication
