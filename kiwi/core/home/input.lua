local KiwiVector = require "kiwi.core.vector"

---@class KiwiHomeInput
---@field position KiwiVector
local KiwiHomeInput = {}

---@return KiwiHomeInput
function KiwiHomeInput.new(position)
    local instance = {position = position}
    setmetatable(instance, {__index = KiwiHomeInput})

    return instance
end

---@param data KiwiHomeInput
function KiwiHomeInput.cast(data)
    if not data.position then
        error("position missing")
    end

    KiwiVector.cast(data.position)

    setmetatable(data, {__index = KiwiHomeInput})

    return data
end

return KiwiHomeInput
