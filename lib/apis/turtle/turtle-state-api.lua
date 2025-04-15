local Vector = require "lib.models.vector"
local State = require "lib.squirtle.state"

---@class TurtleStateApi
local TurtleStateApi = {}

function TurtleStateApi.isSimulating()
    return State.simulate
end

---@return integer
function TurtleStateApi.getFacing()
    if State.simulate then
        return State.simulation.current.facing
    end

    return State.facing
end

---@param facing integer
function TurtleStateApi.setFacing(facing)
    State.facing = facing
end

---@return Vector
function TurtleStateApi.getPosition()
    if State.simulate then
        return Vector.copy(State.simulation.current.position)
    end

    return Vector.copy(State.position)
end

---@param position Vector
function TurtleStateApi.setPosition(position)
    State.position = position
end

---@param delta Vector
function TurtleStateApi.changePosition(delta)
    State.position = Vector.plus(State.position, delta)
end

---@param block Block
---@return boolean
function TurtleStateApi.canBreak(block)
    return State.canBreak(block)
end

--- [todo] rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function TurtleStateApi.setBreakable(predicate)
    return State.setBreakable(predicate)
end

---@return integer | "unlimited"
function TurtleStateApi.getFuelLevel()
    if State.simulate then
        return State.simulation.current.fuel
    end

    return turtle.getFuelLevel()
end

---@return integer
function TurtleStateApi.getNonInfiniteFuelLevel()
    local fuel = TurtleStateApi.getFuelLevel()

    if type(fuel) ~= "number" then
        error("expected to not use unlimited fuel configuration")
    end

    return fuel
end

---@return integer | "unlimited"
function TurtleStateApi.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param fuel integer
---@return boolean
function TurtleStateApi.hasFuel(fuel)
    local level = TurtleStateApi.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function TurtleStateApi.missingFuel(limit)
    local current = TurtleStateApi.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or TurtleStateApi.getFuelLimit()) - current
end

return TurtleStateApi
