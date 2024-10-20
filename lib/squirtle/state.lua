local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"

---@class Simulated
---@field steps integer
---@field placed ItemStock
local SimulationResults = {placed = {}, steps = 0}
---
---@alias DigSide "top" | "front" | "bottom"
---@alias PlaceSide "top" | "front" | "bottom"
---
---@alias OrientationMethod "move"|"disk-drive"
---@alias DiskDriveOrientationSide "top" | "bottom"
---@alias MoveOrientationSide "front" | "back" | "left" | "right"
---@alias OrientationSide DiskDriveOrientationSide | MoveOrientationSide
---
---@class State
---@field breakable? fun(block: Block) : boolean
---@field facing integer
---@field position Vector
---@field orientationMethod OrientationMethod
---@field shulkerSides PlaceSide[]
---In which direction the turtle is allowed to try to break a block in order to place a shulker that could not be placed at front, top or bottom.
---@field breakDirection? "top"|"front"|"bottom"
---If right turns should be left turns and vice versa, useful for mirroring builds.
---@field flipTurns boolean
---@field simulate boolean
---@field results Simulated
---@field simulateUntilPosition Vector? --[todo] unused
---@field simulation Simulation
local State = {
    facing = Cardinal.south,
    position = Vector.create(0, 0, 0),
    orientationMethod = "move",
    flipTurns = false,
    simulate = false,
    results = SimulationResults,
    simulation = {},
    shulkerSides = {"front", "top", "bottom"}
}

---@class Simulation
---@field current SimulationDetails?
---@field initial SimulationDetails?
---@field target SimulationDetails?

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@param block Block
---@return boolean
function State.canBreak(block)
    return breakableSafeguard(block) and (State.breakable == nil or State.breakable(block))
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function State.setBreakable(predicate)
    local current = State.breakable

    local function restore()
        State.breakable = current
    end

    if type(predicate) == "table" then
        State.breakable = function(block)
            for _, item in pairs(predicate) do
                if block.name == item then
                    return true
                end
            end

            return false
        end
    else
        State.breakable = predicate
    end

    return restore
end

---@return boolean
function State.isResuming()
    return (State.simulation.initial and State.simulation.current and State.simulation.target) ~= nil
end

---@return boolean
function State.checkResumeEnd()
    if State.simulation.target and State.simulationCurrentMatchesTarget() then
        State.simulate = false
        State.simulation = {}

        return true
    end

    return false
end

---@return boolean
function State.simulationCurrentMatchesTarget()
    -- [todo] not checking position yet
    local facing = State.simulation.current.facing == State.simulation.target.facing
    local fuel = State.simulation.current.fuel == State.simulation.target.fuel

    -- print(State.simulation.current.fuel, State.simulation.target.fuel)

    return facing and fuel
end

function State.fuelTargetReached()
    return State.simulation.current.fuel == State.simulation.target.fuel
end

function State.facingTargetReached()
    return State.simulation.current.facing == State.simulation.target.facing
end

function State.advanceFuel()
    if State.simulation.current then
        State.simulation.current.fuel = State.simulation.current.fuel - 1
        State.checkResumeEnd()
    end
end

---@param direction string
function State.advanceTurn(direction)
    if State.simulation.current then
        State.simulation.current.facing = Cardinal.rotate(State.simulation.current.facing, direction)
        State.checkResumeEnd()
    end
end

---@param delta Vector
function State.advancePosition(delta)
    if State.simulation.current then
        State.simulation.current.position = Vector.plus(State.simulation.current.position, delta)
        State.checkResumeEnd()
    end
end

return State
