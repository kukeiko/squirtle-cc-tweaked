local nextId = require "lib.tools.next-id"

---@class ShellWindow
---@field id number
---@field title string
---@field fn fun(window: ShellWindow): any
---@field window table
local ShellWindowV3 = {}

---@param title string
---@param fn fun(): any
---@param window table
---@return ShellWindow
function ShellWindowV3.new(title, fn, window)
    ---@type ShellWindow|{}
    local instance = {id = nextId(), title = title, fn = fn, window = window}
    setmetatable(instance, {__index = ShellWindowV3})

    return instance
end

function ShellWindowV3:getId()
    return self.id
end

---@return boolean
function ShellWindowV3:isVisible()
    return self.window.isVisible()
end

---@param isVisible boolean
function ShellWindowV3:setVisible(isVisible)
    self.window.setVisible(isVisible)
end

return ShellWindowV3
