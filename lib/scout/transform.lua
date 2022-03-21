local Vector = require "elements.vector"

---@class Transform
---@field position Vector
---@field facing integer
local Transform = {}

---@param position? Vector
---@param facing? integer
---@return Transform
function Transform.new(position, facing)
    ---@type Transform
    local instance = {position = position or Vector.new(0, 0, 0), facing = facing or 0}

    setmetatable(instance, {__index = Transform})

    return instance
end

return Transform
