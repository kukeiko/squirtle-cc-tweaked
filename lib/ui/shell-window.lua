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
    return self.window.isVisible()
end

---@param isVisible boolean
function ShellWindow:setVisible(isVisible)
    self.window.setVisible(isVisible)
end

return ShellWindow
