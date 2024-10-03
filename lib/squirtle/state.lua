local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"

---@class Simulated
---@field steps integer
---@field placed table<string, integer>
local SimulationResults = {placed = {}, steps = 0}

---@class State
---@field breakable? fun(block: Block) : boolean
---@field facing integer
---@field position Vector
---@field orientationMethod "move"|"disk-drive"
---@field breakDirection? "top"|"front"|"bottom"
---@field flipTurns boolean
---@field simulate boolean
---@field results Simulated
---@field simulateUntilPosition Vector?
---@field simulation Simulation
local State = {
    facing = Cardinal.south,
    position = Vector.create(0, 0, 0),
    orientationMethod = "move",
    flipTurns = false,
    simulate = false,
    results = SimulationResults,
    simulation = {}
}

---@class Simulation
---@field current SimulationDetails?
---@field initial SimulationDetails?
---@field target SimulationDetails?

---@class SimulationDetails
---@field fuel integer
---@field facing integer

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

return State
