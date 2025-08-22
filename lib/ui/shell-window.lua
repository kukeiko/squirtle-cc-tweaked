local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"

---@class ShellWindow
---@field id number
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
    local instance = {id = nextId(), title = title, fn = fn, window = window}
    setmetatable(instance, {__index = ShellWindow})

    return instance
end

function ShellWindow:getId()
    return self.id
end

---@return boolean
function ShellWindow:isVisible()
    -- [todo] ❌ applications like storage use this to figure out if they can do spammy UI stuff, but there is an issue:
    -- a window might be visible, but its application might not be the current one.
    return self.window.isVisible()
end

---@param isVisible boolean
function ShellWindow:setVisible(isVisible)
    self.window.setVisible(isVisible)
end

function ShellWindow:pullIsVisible()
    EventLoop.pull("shell-window:visible")
end

---@param fn fun() : any
function ShellWindow:runUntilInvisible(fn)
    EventLoop.runUntil("shell-window:invisible", fn)
end

return ShellWindow
