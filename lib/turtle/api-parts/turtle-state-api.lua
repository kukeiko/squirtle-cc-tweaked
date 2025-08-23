local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"
local SimulationState = require "lib.turtle.simulation-state"

---@class State
---@field breakable? fun(block: Block) : boolean
---@field facing integer
---@field position Vector
---@field orientationMethod OrientationMethod
---@field shulkerSides PlaceSide[]
---If right turns should be left turns and vice versa, useful for mirroring builds.
---@field flipTurns boolean
---@field simulated SimulationState?
---@field isResuming boolean
---@field shulkers Inventory[]
local State = {
    facing = Cardinal.south,
    position = Vector.create(0, 0, 0),
    orientationMethod = "move",
    flipTurns = false,
    shulkerSides = {"front", "top", "bottom"},
    isResuming = false,
    shulkers = {}
}

---@class TurtleStateApi
local TurtleStateApi = {}

---@return State
function TurtleStateApi.getState()
    return State
end

function TurtleStateApi.isSimulating()
    return State.simulated ~= nil
end

---@return boolean
function TurtleStateApi.isResuming()
    return State.isResuming
end

---@param position Vector
function TurtleStateApi.setPosition(position)
    State.position = position
end

---@return Vector
function TurtleStateApi.getPosition()
    if TurtleStateApi.isSimulating() then
        return Vector.copy(State.simulated.position)
    end

    return Vector.copy(State.position)
end

---@param direction string
---@return Vector
function TurtleStateApi.getPositionTowards(direction)
    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleStateApi.getFacing()))

    return Vector.plus(TurtleStateApi.getPosition(), delta)
end

---@param facing integer
function TurtleStateApi.setFacing(facing)
    State.facing = facing
end

---@param direction "left"|"right"
function TurtleStateApi.changeFacing(direction)
    if TurtleStateApi.isSimulating() then
        error("can't change facing: simulation active")
    end

    State.facing = Cardinal.rotate(State.facing, direction)
end

---@return integer
function TurtleStateApi.getFacing()
    if TurtleStateApi.isSimulating() then
        return State.simulated.facing
    end

    return State.facing
end

---@param side string
---@return integer
function TurtleStateApi.getFacingTowards(side)
    return Cardinal.rotate(TurtleStateApi.getFacing(), side)
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

---@return Inventory[]
function TurtleStateApi.getShulkers()
    return State.shulkers
end

---@param shulkers Inventory[]
function TurtleStateApi.setShulkers(shulkers)
    State.shulkers = shulkers
end

---@param shulker Inventory
function TurtleStateApi.addShulker(shulker)
    table.insert(State.shulkers, shulker)
end

--- [todo] ❌ rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
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

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@param block Block
---@return boolean
function TurtleStateApi.canBreak(block)
    return breakableSafeguard(block) and (State.breakable == nil or State.breakable(block))
end

---@return integer | "unlimited"
function TurtleStateApi.getFuelLevel()
    if TurtleStateApi.isSimulating() then
        return State.simulated.fuel
    end

    return turtle.getFuelLevel()
end

---@return integer
function TurtleStateApi.getFiniteFuelLevel()
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

---@return integer
function TurtleStateApi.getFiniteFuelLimit()
    local fuel = TurtleStateApi.getFuelLimit()

    if type(fuel) ~= "number" then
        error("expected to not use unlimited fuel configuration")
    end

    return fuel
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

    return (limit or TurtleStateApi.getFiniteFuelLimit()) - current
end

function TurtleStateApi.fuelTargetReached()
    return State.simulated.fuel == turtle.getFuelLevel()
end

function TurtleStateApi.facingTargetReached()
    return State.simulated.facing == State.facing
end

function TurtleStateApi.endResume()
    -- not all apps use gps position on resume(), so we need to set actual position based on what we simulated
    TurtleStateApi.setPosition(State.simulated.position)
    State.simulated = nil
    State.isResuming = false
    print("[simulate] end resume")
end

---@return boolean
function TurtleStateApi.checkResumeEnd()
    if TurtleStateApi.isResuming() and TurtleStateApi.fuelTargetReached() and TurtleStateApi.facingTargetReached() then
        TurtleStateApi.endResume()
        return true
    end

    return false
end

---@param fn fun() : nil
---@return SimulationResults
function TurtleStateApi.simulate(fn)
    if TurtleStateApi.isSimulating() then
        error("can't begin simulation: already simulating")
    end

    print("[simulate] enabling simulation...")
    local actualFuel = TurtleStateApi.getFiniteFuelLevel()
    State.simulated = SimulationState.construct(actualFuel, State.facing, State.position)
    fn()
    local results = SimulationState.getResults(State.simulated, actualFuel)
    State.simulated = nil
    print("[simulate] ending simulation")

    return results
end

---@param fuel integer
---@param facing integer
---@param position Vector
function TurtleStateApi.resume(fuel, facing, position)
    if TurtleStateApi.isSimulating() then
        error("can't begin simulation: already simulating")
    end

    print("[simulate] enabling resume...")
    State.isResuming = true
    State.simulated = SimulationState.construct(fuel, facing, position)
    TurtleStateApi.checkResumeEnd()
end

---@param block string
---@param quantity? integer
function TurtleStateApi.recordPlacedBlock(block, quantity)
    SimulationState.recordPlacedBlock(State.simulated, block, quantity)
end

---@param block string
---@param quantity? integer
function TurtleStateApi.recordTakenBlock(block, quantity)
    SimulationState.recordTakenBlock(State.simulated, block, quantity)
end

function TurtleStateApi.placeWater()
    SimulationState.placeWater(State.simulated)
end

function TurtleStateApi.takeWater()
    SimulationState.takeWater(State.simulated)
end

function TurtleStateApi.placeLava()
    SimulationState.placeLava(State.simulated)
end

function TurtleStateApi.takeLava()
    SimulationState.takeLava(State.simulated)
end

return TurtleStateApi
