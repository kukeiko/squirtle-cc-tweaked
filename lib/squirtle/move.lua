local Side = require "elements.side"
local Cardinal = require "elements.cardinal"
local getState = require "squirtle.get-state"
local changeState = require "squirtle.change-state"
local Fuel = require "squirtle.fuel"
local refuel = require "squirtle.refuel"
local native = turtle

---@class SquirtleMoveOptions
---@field attack? boolean
---@field dig? boolean|function

local natives = {
    [Side.top] = native.up,
    [Side.front] = native.forward,
    [Side.bottom] = native.down,
    [Side.back] = native.back
}

---@param side? integer|string
---@param times? integer
---@param options? SquirtleMoveOptions
return function(side, times, options)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("move() does not support side %s", Side.getName(side)))
    end

    times = times or 1

    if not Fuel.hasFuel(times) then
        refuel(times)
    end

    local state = getState()
    local delta

    if state.position and state.facing then
        position = state.position
        delta = Cardinal.toVector(Cardinal.fromSide(side, state.facing))
    end

    for step = 1, times do
        local success, message = handler()

        if not success then
            return false, message, step
        end

        if delta then
            position = position + delta
            changeState({position = position})
        end
    end

    return true
end