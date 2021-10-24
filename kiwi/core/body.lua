local KiwiVector = require "kiwi.core.vector"

---@class KiwiBody
---@field position KiwiVector
---@field facing integer
local KiwiBody = {}

---@param position? KiwiVector
---@param facing? integer
---@return KiwiBody
function KiwiBody.new(position, facing)
    ---@type Transform
    local instance = {position = position or KiwiVector.new(0, 0, 0), facing = facing or 0}

    setmetatable(instance, {__index = KiwiBody})

    return instance
end

return KiwiBody
