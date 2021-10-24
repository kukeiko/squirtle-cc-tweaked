local KiwiVector = require "kiwi.core.vector"

---@class KiwiHomeBuffer
---@field position KiwiVector
local KiwiHomeBuffer = {}

---@return KiwiHomeBuffer
function KiwiHomeBuffer.new(position)
    local instance = {position = position}
    setmetatable(instance, {__index = KiwiHomeBuffer})

    return instance
end

---@param data KiwiHomeBuffer
function KiwiHomeBuffer.cast(data)
    if not data.position then
        error("position missing")
    end

    KiwiVector.cast(data.position)

    setmetatable(data, {__index = KiwiHomeBuffer})

    return data
end

return KiwiHomeBuffer
