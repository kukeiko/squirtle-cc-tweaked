local Vector = require "squirtle.libs.vector"

-- [todo] need to think about if we wanna have the Transform class be mutable
-- [todo] consider renaming to "Body" - or something similarly easier to understand,
-- because "Transform" doesn't give you too much of an idea

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
