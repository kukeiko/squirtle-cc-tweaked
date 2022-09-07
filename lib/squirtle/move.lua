local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local getState = require "squirtle.get-state"
local changeState = require "squirtle.change-state"
local Fuel = require "squirtle.fuel"
local refuel = require "squirtle.refuel"

local natives = {
    top = turtle.up,
    up = turtle.up,
    front = turtle.forward,
    forward = turtle.forward,
    bottom = turtle.down,
    down = turtle.down,
    back = turtle.back
}

-- [todo] move() should not call refuel like this. instead, a refueler interface should be provided.
-- if no fuel could be acquired via the refueler, and there is not enough fuel, error out.
---@param side? string
---@param times? integer
return function(side, times)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("move() does not support side %s", side))
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
            position = Vector.plus(position, delta)
            changeState({position = position})
        end
    end

    return true
end
