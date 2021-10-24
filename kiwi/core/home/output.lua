local KiwiVector = require "kiwi.core.vector"

---@class KiwiHomeOutput
---@field position KiwiVector
---@field hopperMinecartConnected? boolean
local KiwiHomeOutput = {}

---@return KiwiHomeOutput
function KiwiHomeOutput.new(position, hopperMinecartConnected)
    local instance = {position = position, hopperMinecartConnected = hopperMinecartConnected}
    setmetatable(instance, {__index = KiwiHomeOutput})

    return instance
end

---@param data KiwiHomeOutput
function KiwiHomeOutput.cast(data)
    if not data.position then
        error("position missing")
    end

    KiwiVector.cast(data.position)

    if data.hopperMinecartConnected ~= nil and type(data.hopperMinecartConnected) ~= "boolean" then
        error("hopperMinecartConnected not a boolean")
    end

    setmetatable(data, {__index = KiwiHomeOutput})

    return data
end

return KiwiHomeOutput
