local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local State = require "lib.squirtle.state"

---@class TurtleStateApi
local TurtleStateApi = {}

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@return integer
function TurtleStateApi.getFacing()
    if TurtleStateApi.isSimulating() then
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
    if TurtleStateApi.isSimulating() then
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

---@class TurtleConfigurationOptions
---@field orientate? "move"|"disk-drive"
---@field breakDirection? "top"|"front"|"bottom"
---@field shulkerSides? PlaceSide[]
---@param options TurtleConfigurationOptions
function TurtleStateApi.configure(options)
    if options.orientate then
        TurtleStateApi.setOrientationMethod(options.orientate)
    end

    if options.breakDirection then
        TurtleStateApi.setBreakDirection(options.breakDirection)
    end

    if options.shulkerSides then
        TurtleStateApi.setShulkerSides(options.shulkerSides)
    end
end

---@param block Block
---@return boolean
function TurtleStateApi.canBreak(block)
    return breakableSafeguard(block) and (State.breakable == nil or State.breakable(block))
end

--- [todo] rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function TurtleStateApi.setBreakable(predicate)
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

---@param flipTurns boolean
function TurtleStateApi.setFlipTurns(flipTurns)
    State.flipTurns = flipTurns
end

---@return boolean
function TurtleStateApi.getFlipTurns()
    return State.flipTurns
end

---@param orientationMethod OrientationMethod
function TurtleStateApi.setOrientationMethod(orientationMethod)
    State.orientationMethod = orientationMethod
end

---@return OrientationMethod
function TurtleStateApi.getOrientationMethod()
    return State.orientationMethod
end

---@param shulkerSides PlaceSide[]
function TurtleStateApi.setShulkerSides(shulkerSides)
    State.shulkerSides = shulkerSides
end

---@return PlaceSide[]
function TurtleStateApi.getShulkerSides()
    return State.shulkerSides
end
---@param breakDirection "top"|"front"|"bottom"|nil
function TurtleStateApi.setBreakDirection(breakDirection)
    State.breakDirection = breakDirection
end

---@return "top"|"front"|"bottom"|nil
function TurtleStateApi.getBreakDirection()
    return State.breakDirection
end

---@return integer | "unlimited"
function TurtleStateApi.getFuelLevel()
    if TurtleStateApi.isSimulating() then
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

function TurtleStateApi.isSimulating()
    return State.simulation ~= nil
end

---@return boolean
local function checkResumeEnd()
    if TurtleStateApi.isResuming() and TurtleStateApi.simulationCurrentMatchesTarget() then
        State.simulation = nil

        print("[simulate] end simulation")
        return true
    end

    return false
end

---@param initialState? SimulationState
---@param targetState? SimulationState
function TurtleStateApi.beginSimulation(initialState, targetState)
    if TurtleStateApi.isSimulating() then
        error("can't begin simulation: already simulating")
    end

    ---@type SimulationState
    local current = initialState or
                        {
            facing = TurtleStateApi.getFacing(),
            fuel = TurtleStateApi.getNonInfiniteFuelLevel(),
            position = TurtleStateApi.getPosition()
        }

    State.simulation = {current = current, target = targetState}

    if targetState then
        checkResumeEnd()
    end
end

---@return Simulated
function TurtleStateApi.endSimulation()
    if not TurtleStateApi.isSimulating() then
        error("can't end simulation: not simulating")
    end

    State.simulation = nil

    return State.results
end

---@return boolean
function TurtleStateApi.simulationCurrentMatchesTarget()
    -- [todo] not checking position yet
    local facing = State.simulation.current.facing == State.simulation.target.facing
    local fuel = State.simulation.current.fuel == State.simulation.target.fuel

    -- print(State.simulation.current.fuel, State.simulation.target.fuel)

    return facing and fuel
end

function TurtleStateApi.fuelTargetReached()
    return State.simulation.current.fuel == State.simulation.target.fuel
end

function TurtleStateApi.facingTargetReached()
    return State.simulation.current.facing == State.simulation.target.facing
end

---@return boolean
function TurtleStateApi.isResuming()
    return TurtleStateApi.isSimulating() and State.simulation.target ~= nil
end

function TurtleStateApi.advanceFuel()
    if State.simulation.current then
        State.simulation.current.fuel = State.simulation.current.fuel - 1
        checkResumeEnd()
    end
end

---@param direction string
function TurtleStateApi.advanceTurn(direction)
    if State.simulation.current then
        State.simulation.current.facing = Cardinal.rotate(State.simulation.current.facing, direction)
        checkResumeEnd()
    end
end

---@param delta Vector
function TurtleStateApi.advancePosition(delta)
    if State.simulation.current then
        State.simulation.current.position = Vector.plus(State.simulation.current.position, delta)
        checkResumeEnd()
    end
end

---@param block string
---@param quantity? integer
function TurtleStateApi.recordPlacedBlock(block, quantity)
    State.results.placed[block] = (State.results.placed[block] or 0) + (quantity or 1)
end

return TurtleStateApi
