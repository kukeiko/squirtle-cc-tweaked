local HomeOutput = require "kiwi.core.home.output"
local HomeInput = require "kiwi.core.home.input"
local HomeBuffer = require "kiwi.core.home.buffer"
local KiwiVector = require "kiwi.core.vector"

---@class KiwiHome
---@field position KiwiVector
---@field output KiwiHomeOutput
---@field input KiwiHomeInput
---@field buffer KiwiHomeBuffer
local KiwiHome = {}

---@return KiwiHome
function KiwiHome.new(output, input, buffer)
    ---@type KiwiHome
    local instance = {output = output, input = input, buffer = buffer}
    setmetatable(instance, {__index = KiwiHome})
    return instance
end

---@param data KiwiHome
function KiwiHome.cast(data)
    KiwiVector.cast(data.position)

    if data.output then
        data.output = HomeOutput.cast(data.output)
    end

    if data.input then
        HomeInput.cast(data.input)
    end

    if data.buffer then
        HomeBuffer.cast(data.buffer)
    end

    setmetatable(data, {__index = KiwiHome})

    return data
end

return KiwiHome
