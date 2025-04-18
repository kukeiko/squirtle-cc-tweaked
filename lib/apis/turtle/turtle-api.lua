local Utils = require "lib.tools.utils"
local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local World = require "lib.models.world"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local DatabaseApi = require "lib.apis.database.database-api"
local getNative = require "lib.apis.turtle.functions.get-native"
local findPath = require "lib.apis.turtle.functions.find-path"
local digArea = require "lib.apis.turtle.functions.dig-area"
local requireItems = require "lib.apis.turtle.functions.require-items"
local runResumable = require "lib.apis.turtle.functions.run-resumable"

local bucket = "minecraft:bucket"
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@class Simulated
---@field steps integer
---@field placed ItemStock
local SimulationResults = {placed = {}, steps = 0}
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
---@field results Simulated
---@field simulation Simulation?
local State = {
    facing = Cardinal.south,
    position = Vector.create(0, 0, 0),
    orientationMethod = "move",
    flipTurns = false,
    results = SimulationResults,
    shulkerSides = {"front", "top", "bottom"}
}

---@class Simulation
---@field current SimulationState
---@field target SimulationState?

---@class TurtleApi
local TurtleApi = {}

local function assertNotSimulating(fnName)
    if TurtleApi.isSimulating() then
        error(string.format("%s() does not support simulation", fnName))
    end
end

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@return integer
function TurtleApi.getFacing()
    if TurtleApi.isSimulating() then
        return State.simulation.current.facing
    end

    return State.facing
end

---@param side string
function TurtleApi.getFacingTowards(side)
    return Cardinal.rotate(TurtleApi.getFacing(), side)
end

---@param facing integer
function TurtleApi.setFacing(facing)
    State.facing = facing
end

---@param direction "left"|"right"
function TurtleApi.changeFacing(direction)
    if TurtleApi.isSimulating() then
        error("can't change facing: simulation active")
    end

    State.facing = Cardinal.rotate(State.facing, direction)
end

---@return Vector
function TurtleApi.getPosition()
    if TurtleApi.isSimulating() then
        return Vector.copy(State.simulation.current.position)
    end

    return Vector.copy(State.position)
end

---@param direction string
---@return Vector
function TurtleApi.getPositionTowards(direction)
    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleApi.getFacing()))

    return Vector.plus(TurtleApi.getPosition(), delta)
end

---@param position Vector
function TurtleApi.setPosition(position)
    State.position = position
end

---@param direction MoveDirection
function TurtleApi.changePosition(direction)
    if TurtleApi.isSimulating() then
        error("can't change position: simulation active")
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, State.facing))
    State.position = Vector.plus(State.position, delta)
end

---@class TurtleConfigurationOptions
---@field orientate? "move"|"disk-drive"
---@field breakDirection? "top"|"front"|"bottom"
---@field shulkerSides? PlaceSide[]
---@param options TurtleConfigurationOptions
function TurtleApi.configure(options)
    if options.orientate then
        TurtleApi.setOrientationMethod(options.orientate)
    end

    if options.breakDirection then
        TurtleApi.setBreakDirection(options.breakDirection)
    end

    if options.shulkerSides then
        TurtleApi.setShulkerSides(options.shulkerSides)
    end
end

---@param block Block
---@return boolean
function TurtleApi.canBreak(block)
    return breakableSafeguard(block) and (State.breakable == nil or State.breakable(block))
end

--- [todo] rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function TurtleApi.setBreakable(predicate)
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
function TurtleApi.setFlipTurns(flipTurns)
    State.flipTurns = flipTurns
end

---@return boolean
function TurtleApi.getFlipTurns()
    return State.flipTurns
end

---@param orientationMethod OrientationMethod
function TurtleApi.setOrientationMethod(orientationMethod)
    State.orientationMethod = orientationMethod
end

---@return OrientationMethod
function TurtleApi.getOrientationMethod()
    return State.orientationMethod
end

---@param shulkerSides PlaceSide[]
function TurtleApi.setShulkerSides(shulkerSides)
    State.shulkerSides = shulkerSides
end

---@return PlaceSide[]
function TurtleApi.getShulkerSides()
    return State.shulkerSides
end
---@param breakDirection "top"|"front"|"bottom"|nil
function TurtleApi.setBreakDirection(breakDirection)
    State.breakDirection = breakDirection
end

---@return "top"|"front"|"bottom"|nil
function TurtleApi.getBreakDirection()
    return State.breakDirection
end

---@return integer | "unlimited"
function TurtleApi.getFuelLevel()
    if TurtleApi.isSimulating() then
        return State.simulation.current.fuel
    end

    return turtle.getFuelLevel()
end

---@return integer
function TurtleApi.getNonInfiniteFuelLevel()
    local fuel = TurtleApi.getFuelLevel()

    if type(fuel) ~= "number" then
        error("expected to not use unlimited fuel configuration")
    end

    return fuel
end

---@return integer | "unlimited"
function TurtleApi.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param fuel integer
---@return boolean
function TurtleApi.hasFuel(fuel)
    local level = TurtleApi.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function TurtleApi.missingFuel(limit)
    local current = TurtleApi.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or TurtleApi.getFuelLimit()) - current
end

function TurtleApi.isSimulating()
    return State.simulation ~= nil
end

---@return boolean
local function checkResumeEnd()
    if TurtleApi.isResuming() and TurtleApi.simulationCurrentMatchesTarget() then
        -- not all apps use gps position on resume(), so we need to set actual position based on what we simulated
        TurtleApi.setPosition(State.simulation.current.position)
        State.simulation = nil
        print("[simulate] end simulation")
        return true
    end

    return false
end

---@param initialState? SimulationState
---@param targetState? SimulationState
function TurtleApi.beginSimulation(initialState, targetState)
    if TurtleApi.isSimulating() then
        error("can't begin simulation: already simulating")
    end

    print("[simulate] enabling simulation...")

    if not initialState then
        initialState = {facing = TurtleApi.getFacing(), fuel = TurtleApi.getNonInfiniteFuelLevel(), position = TurtleApi.getPosition()}
    end

    State.simulation = {current = initialState, target = targetState}

    if targetState then
        checkResumeEnd()
    end
end

---@return Simulated
function TurtleApi.endSimulation()
    if not TurtleApi.isSimulating() then
        error("can't end simulation: not simulating")
    end

    print("[simulate] simulation ended")
    State.simulation = nil

    return State.results
end

---@return boolean
function TurtleApi.simulationCurrentMatchesTarget()
    local facing = State.simulation.current.facing == State.simulation.target.facing
    local fuel = State.simulation.current.fuel == State.simulation.target.fuel

    return facing and fuel
end

function TurtleApi.fuelTargetReached()
    return State.simulation.current.fuel == State.simulation.target.fuel
end

function TurtleApi.facingTargetReached()
    return State.simulation.current.facing == State.simulation.target.facing
end

---@return boolean
function TurtleApi.isResuming()
    return TurtleApi.isSimulating() and State.simulation.target ~= nil
end

---@param direction string
function TurtleApi.simulateMove(direction)
    if not TurtleApi.isSimulating() then
        error("can't simulate move: not simulating")
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleApi.getFacing()))
    State.simulation.current.fuel = State.simulation.current.fuel - 1
    State.simulation.current.position = Vector.plus(State.simulation.current.position, delta)
    checkResumeEnd()
end

---@param direction string
function TurtleApi.simulateTurn(direction)
    if not TurtleApi.isSimulating() then
        error("can't simulate turn: not simulating")
    end

    State.simulation.current.facing = Cardinal.rotate(State.simulation.current.facing, direction)
    checkResumeEnd()
end

---@param block string
---@param quantity? integer
function TurtleApi.recordPlacedBlock(block, quantity)
    State.results.placed[block] = (State.results.placed[block] or 0) + (quantity or 1)
end

---Turns 1x time towards direction "back", "left" or "right".
---If flipTurns is on, "left" will become "right" and vice versa.
---@param direction string
function TurtleApi.turn(direction)
    if direction == "back" then
        TurtleApi.turn("left")
        TurtleApi.turn("left")
    elseif direction == "left" or direction == "right" then
        if TurtleApi.getFlipTurns() then
            if direction == "left" then
                direction = "right"
            elseif direction == "right" then
                direction = "left"
            end
        end

        if TurtleApi.isSimulating() then
            TurtleApi.simulateTurn(direction)
        else
            getNative("turn", direction)()
            TurtleApi.changeFacing(direction)
        end
    end
end

---@param target integer
function TurtleApi.face(target)
    local current = TurtleApi.getFacing()

    if (current + 2) % 4 == target then
        TurtleApi.turn("back")
    elseif (current + 1) % 4 == target then
        TurtleApi.turn("right")
    elseif (current - 1) % 4 == target then
        TurtleApi.turn("left")
    end

    return target
end

---@param quantity? integer
---@return boolean, string?
function TurtleApi.refuel(quantity)
    return turtle.refuel(quantity)
end

---@param stacks ItemStack[]
---@param fuel number
---@param allowLava? boolean
---@return ItemStack[] fuelStacks, number openFuel
local function pickFuelStacks(stacks, fuel, allowLava)
    local pickedStacks = {}
    local openFuel = fuel

    for slot, stack in pairs(stacks) do
        if fuelItems[stack.name] and (allowLava or stack.name ~= "minecraft:lava_bucket") then
            local itemRefuelAmount = fuelItems[stack.name]
            local numItems = math.ceil(openFuel / itemRefuelAmount)
            stack = Utils.clone(stack)
            stack.count = numItems
            pickedStacks[slot] = stack
            openFuel = openFuel - (numItems * itemRefuelAmount)

            if openFuel <= 0 then
                break
            end
        end
    end

    return pickedStacks, math.max(openFuel, 0)
end

---@param fuel? integer
---@param allowLava? boolean
local function refuelFromBackpack(fuel, allowLava)
    fuel = fuel or TurtleApi.missingFuel()
    local fuelStacks = pickFuelStacks(TurtleApi.getStacks(), fuel, allowLava)
    local emptyBucketSlot = TurtleApi.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        TurtleApi.select(slot)
        TurtleApi.refuel(stack.count)

        local remaining = TurtleApi.getStack(slot)

        if remaining and remaining.name == bucket then
            if not emptyBucketSlot or not TurtleApi.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or TurtleApi.missingFuel()
    local _, y = term.getCursorPos()

    while not TurtleApi.hasFuel(fuel) do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - TurtleApi.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function TurtleApi.refuelTo(fuel)
    if TurtleApi.hasFuel(fuel) then
        return true
    elseif fuel > TurtleApi.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - TurtleApi.getFuelLimit()))
    end

    refuelFromBackpack(fuel)

    if not TurtleApi.hasFuel(fuel) then
        refuelWithHelpFromPlayer(fuel)
    end
end

---@param action string
---@param direction MoveDirection
---@param steps integer
---@param stepsTaken integer
---@param originalMessage? string
---@return string
local function getGoErrorMessage(action, direction, steps, stepsTaken, originalMessage)
    originalMessage = originalMessage or "(unknown error)"

    if steps == 1 then
        return string.format("failed to %s once towards %s: %s", action, direction, originalMessage)
    else
        return string.format("failed to %s %d steps (%d steps taken) towards %s: %s", action, steps, stepsTaken, direction, originalMessage)
    end
end

---Move towards the given direction without trying to remove any obstacles found. Will prompt for fuel if there isn't enough.
---If simulation is active, will always return false with 0 steps taken.
---@param direction? MoveDirection
---@param steps? integer
---@return boolean success, integer stepsTaken, string? error
function TurtleApi.tryWalk(direction, steps)
    direction = direction or "forward"
    local native = getNative("go", direction)
    steps = steps or 1

    if TurtleApi.isSimulating() then
        -- [note] "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    end

    if not TurtleApi.hasFuel(steps) then
        TurtleApi.refuelTo(steps)
    end

    for step = 1, steps do
        local success, message = native()

        if success then
            TurtleApi.changePosition(direction)
        else
            return false, step - 1, message
        end
    end

    return true, steps
end

---Move towards the given direction without trying to remove any obstacles found. Will prompt for fuel if there isn't enough.
---Throws an error if it failed to move all steps.
---If simulation is active, will always throw.
---@param direction? MoveDirection
---@param steps? integer
function TurtleApi.walk(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleApi.tryWalk(direction, steps)

    if success then
        return nil
    end

    -- [todo] will always throw if simulation is active - is that intended?
    error(getGoErrorMessage("walk", direction, steps, stepsTaken, message))
end

---@param steps integer?
---@return boolean, integer, string?
local function tryMoveBack(steps)
    steps = steps or 1
    local native = getNative("go", "back")
    local didTurnBack = false

    for step = 1, steps do
        if TurtleApi.isResuming() and TurtleApi.fuelTargetReached() and not TurtleApi.facingTargetReached() then
            -- we seem to be in correct position but the facing is off, meaning that there must've been
            -- a block that caused us to turn to try and mine it. in order to resume, we'll just
            -- stop the simulation and orient the turtle so that the turning code gets run from the beginning.
            local facing = TurtleApi.getFacing()
            TurtleApi.endSimulation()
            TurtleApi.face(facing)
        end

        if TurtleApi.isSimulating() then
            TurtleApi.simulateMove("back")
        else
            while not native() do
                if not didTurnBack then
                    TurtleApi.turn("right")
                    TurtleApi.turn("right")
                    direction = "forward"
                    native = getNative("go", "forward")
                    didTurnBack = true
                end

                while TurtleApi.tryMine(direction) do
                end

                local block = TurtleApi.probe(direction)

                if block and not TurtleApi.canBreak(block) then
                    TurtleApi.turn("left")
                    TurtleApi.turn("left")

                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            TurtleApi.changePosition("back")
        end
    end

    if didTurnBack then
        TurtleApi.turn("left")
        TurtleApi.turn("left")
    end

    return true, steps
end

---[todo] tryMove() should throw an error if called directly when simulating. since move() can be called while simulating,
---i'll need to move the function body out so move() can still call it.
---@param direction MoveDirection?
---@param steps integer?
---@return boolean, integer, string?
function TurtleApi.tryMove(direction, steps)
    steps = steps or 1

    if not TurtleApi.isSimulating() and not TurtleApi.hasFuel(steps) then
        TurtleApi.refuelTo(steps)
    end

    if direction == "back" then
        return tryMoveBack(steps)
    end

    direction = direction or "forward"
    local native = getNative("go", direction)

    for step = 1, steps do
        if TurtleApi.isSimulating() then
            TurtleApi.simulateMove(direction)
        else
            while not native() do
                while TurtleApi.tryMine(direction) do
                end

                local block = TurtleApi.probe(direction)

                if block and not TurtleApi.canBreak(block) then
                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            TurtleApi.changePosition(direction)
        end
    end

    return true, steps
end

---@param direction? MoveDirection
---@param steps? integer
function TurtleApi.move(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleApi.tryMove(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("move", direction, steps, stepsTaken, message))
end

---@param target Vector
---@return boolean, string?
function TurtleApi.tryMoveToPoint(target)
    local delta = Vector.minus(target, TurtleApi.getPosition())

    if delta.y > 0 then
        if not TurtleApi.tryMove("up", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not TurtleApi.tryMove("down", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        TurtleApi.face(Cardinal.east)
        if not TurtleApi.tryMove("forward", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        TurtleApi.face(Cardinal.west)
        if not TurtleApi.tryMove("forward", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        TurtleApi.face(Cardinal.south)

        if not TurtleApi.tryMove("forward", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        TurtleApi.face(Cardinal.north)

        if not TurtleApi.tryMove("forward", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param target Vector
function TurtleApi.moveToPoint(target)
    if not TurtleApi.tryMoveToPoint(target) then
        error(string.format("failed to move to %d/%d/%d", target.x, target.y, target.z))
    end
end

---@param path Vector[]
---@return boolean, string?, integer?
local function tryMovePath(path)
    for i, next in ipairs(path) do
        local success, failedSide = TurtleApi.tryMoveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function TurtleApi.navigate(to, world, breakable)
    breakable = breakable or function()
        return false
    end

    local restoreBreakable = TurtleApi.setBreakable(breakable)

    if not world then
        local position = TurtleApi.getPosition()
        world = World.create(position.x, position.y, position.z)
    end

    local from = TurtleApi.getPosition()
    local facing = TurtleApi.getFacing()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            restoreBreakable()
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        TurtleApi.refuelTo(distance)
        local success, failedSide = tryMovePath(path)

        if success then
            restoreBreakable()
            return true
        elseif failedSide then
            from = TurtleApi.getPosition()
            facing = TurtleApi.getFacing()
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))
            World.setBlock(world, scannedLocation)
        end
    end
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function TurtleApi.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if TurtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and TurtleApi.tryWalk("up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and TurtleApi.tryWalk("down") then
            strategy = "down"
            forbidden = "up"
        elseif TurtleApi.turn("left") and TurtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleApi.turn("left") and forbidden ~= "back" and TurtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleApi.turn("left") and TurtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while TurtleApi.tryWalk("forward") do
            end
        elseif strategy == "up" then
            while TurtleApi.tryWalk("up") do
            end
        elseif strategy == "down" then
            while TurtleApi.tryWalk("down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

---Returns the block towards the given direction. If a name is given, the block has to match it or nil is returned.
---"name" can either be a string or a table of strings.
---@param direction? string
---@param name? table|string
---@return Block? block
function TurtleApi.probe(direction, name)
    direction = direction or "front"
    local success, block = getNative("inspect", direction)()

    if not success then
        return nil
    end

    if not name then
        return block
    end

    if type(name) == "string" and block.name == name then
        return block
    elseif type(name) == "table" and Utils.indexOf(name, block.name) then
        return block
    end
end

---@param direction? string
---@param tool? string
---@return boolean, string?
function TurtleApi.dig(direction, tool)
    if TurtleApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("dig", direction)(tool)
end

---@param directions DigSide[]
---@return string? dugDirection
function TurtleApi.digAtOneOf(directions)
    for i = 1, #directions do
        if TurtleApi.dig(directions[i]) then
            return directions[i]
        end
    end
end

---Throws an error if:
--- - no digging tool is equipped
---@param direction? string
---@return boolean success, string? error
function TurtleApi.tryMine(direction)
    if TurtleApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    local native = getNative("dig", direction)
    local block = TurtleApi.probe(direction)

    if not block then
        return false
    elseif not TurtleApi.canBreak(block) then
        return false, string.format("not allowed to mine block %s", block.name)
    end

    local success, message = native()

    if not success then
        if message == "Nothing to dig here" then
            return false
        elseif string.match(message, "tool") then
            error(string.format("failed to mine %s: %s", direction, message))
        end
    end

    return success, message
end

---Throws an error if:
--- - no digging tool is equipped
--- - turtle is not allowed to dig the block
---@param direction? string
---@return boolean success
function TurtleApi.mine(direction)
    local success, message = TurtleApi.tryMine(direction)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---@param depth integer
---@param width integer
---@param height integer
---@param homePosition? Vector
---@param homeFacing? integer
function TurtleApi.digArea(depth, width, height, homePosition, homeFacing)
    return digArea(TurtleApi, depth, width, height, homePosition, homeFacing)
end

---@param direction? string
---@param text? string
---@return boolean, string?
function TurtleApi.place(direction, text)
    if TurtleApi.isSimulating() then
        return true
    end

    direction = direction or "front"
    return getNative("place", direction)(text)
end

---@param directions PlaceSide[]
---@return string? placedDirection
function TurtleApi.placeAtOneOf(directions)
    assertNotSimulating("placeAtOneOf")

    for i = 1, #directions do
        if TurtleApi.place(directions[i]) then
            return directions[i]
        end
    end
end

---@param side? string
---@param text? string
---@return boolean, string?
function TurtleApi.tryReplace(side, text)
    if TurtleApi.isSimulating() then
        return true
    end

    if TurtleApi.place(side, text) then
        return true
    end

    while TurtleApi.tryMine(side) do
    end

    return TurtleApi.place(side, text)
end

---@param sides? string[]
---@param text? string
---@return string?
function TurtleApi.tryReplaceAtOneOf(sides, text)
    assertNotSimulating("tryReplaceAtOneOf")
    sides = sides or {"top", "front", "bottom"}

    for i = 1, #sides do
        local side = sides[i]

        if TurtleApi.place(side, text) then
            return side
        end
    end

    -- [todo] tryPut() is attacking - should we do it here as well?
    for i = 1, #sides do
        local side = sides[i]

        while TurtleApi.tryMine(side) do
        end

        if TurtleApi.place(side, text) then
            return side
        end
    end
end

---@param block? string
---@return boolean
local function simulateTryPut(block)
    if block then
        TurtleApi.recordPlacedBlock(block)
    end

    return true
end

---@param block? string
local function simulatePut(block)
    simulateTryPut(block)
end

---@param side? string
---@param block? string
---@return boolean
function TurtleApi.tryPut(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if TurtleApi.isSimulating() then
        return simulateTryPut(block)
    end

    if block then
        while not TurtleApi.selectItem(block) do
            TurtleApi.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while TurtleApi.tryMine(side) do
    end

    -- [todo] band-aid fix
    while turtle.attack() do
        os.sleep(1)
    end

    return native()
end

---@param side? string
---@param block? string
function TurtleApi.put(side, block)
    if TurtleApi.isSimulating() then
        return simulatePut(block)
    end

    if not TurtleApi.tryPut(side, block) then
        error("failed to place")
    end
end

---@param sides? PlaceSide[]
---@param block? string
---@return PlaceSide? placedDirection
function TurtleApi.tryPutAtOneOf(sides, block)
    if TurtleApi.isSimulating() then
        -- [todo] reconsider if this method should really be simulatable, as its outcome depends on world state
        return simulatePut(block)
    end

    sides = sides or {"top", "front", "bottom"}

    if block then
        while not TurtleApi.selectItem(block) do
            TurtleApi.requireItem(block)
        end
    end

    for i = 1, #sides do
        local native = getNative("place", sides[i])

        if native() then
            return sides[i]
        end
    end

    -- [todo] tryPut() is attacking - should we do it here as well?
    for i = 1, #sides do
        local native = getNative("place", sides[i])

        while TurtleApi.tryMine(sides[i]) do
        end

        if native() then
            return sides[i]
        end
    end
end

---@return integer
function TurtleApi.size()
    return 16
end

---@param slot? integer
---@return integer
function TurtleApi.getItemCount(slot)
    return turtle.getItemCount(slot)
end

---@param slot? integer
---@return integer
function TurtleApi.getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

---@param slot integer
---@return boolean
function TurtleApi.select(slot)
    if TurtleApi.isSimulating() then
        return true
    end

    return turtle.select(slot)
end

---@return integer
function TurtleApi.getSelectedSlot()
    return turtle.getSelectedSlot()
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function TurtleApi.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param quantity? integer
---@return boolean
function TurtleApi.transferTo(slot, quantity)
    return turtle.transferTo(slot, quantity)
end

---@param slot integer
---@return boolean
function TurtleApi.selectIfNotEmpty(slot)
    if TurtleApi.getItemCount(slot) > 0 then
        return TurtleApi.select(slot)
    else
        return false
    end
end

---@param startAt? number
---@return integer
function TurtleApi.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, TurtleApi.size() - 1 do
        local slot = startAt + i

        if slot > TurtleApi.size() then
            slot = slot - TurtleApi.size()
        end

        if TurtleApi.getItemCount(slot) == 0 then
            TurtleApi.select(slot)

            return slot
        end
    end

    error("no empty slot available")
end

---@return integer
function TurtleApi.selectFirstEmpty()
    return TurtleApi.selectEmpty(1)
end

---@param startAt? number
function TurtleApi.firstEmptySlot(startAt)
    -- [todo] this startAt logic works a bit differently to "Backpack.selectEmpty()" as it does not wrap around
    startAt = startAt or 1

    for slot = startAt, TurtleApi.size() do
        if TurtleApi.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return integer
function TurtleApi.numEmptySlots()
    local numEmpty = 0

    for slot = 1, TurtleApi.size() do
        if TurtleApi.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function TurtleApi.isFull()
    for slot = 1, TurtleApi.size() do
        if TurtleApi.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@return boolean
function TurtleApi.isEmpty()
    for slot = 1, TurtleApi.size() do
        if TurtleApi.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

---@return ItemStack[]
function TurtleApi.getStacks()
    local stacks = {}

    for slot = 1, TurtleApi.size() do
        local item = TurtleApi.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function TurtleApi.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(TurtleApi.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@return table<string, integer>
function TurtleApi.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(TurtleApi.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
---@return integer?
function TurtleApi.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, TurtleApi.size() do
        local item = TurtleApi.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end

---@param item string
---@param minCount? integer
---@return boolean
function TurtleApi.has(item, minCount)
    if type(minCount) == "number" then
        return TurtleApi.getItemStock(item) >= minCount
    else
        for slot = 1, TurtleApi.size() do
            local stack = TurtleApi.getStack(slot)

            if stack and stack.name == item then
                return true
            end
        end

        return false
    end
end

---Condenses the inventory by stacking matching items.
function TurtleApi.condense()
    if TurtleApi.isSimulating() then
        return nil
    end

    for slot = TurtleApi.size(), 1, -1 do
        local item = TurtleApi.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = TurtleApi.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    TurtleApi.select(slot)
                    TurtleApi.transferTo(targetSlot)

                    if TurtleApi.getItemCount(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    TurtleApi.select(slot)
                    TurtleApi.transferTo(targetSlot)
                    break
                end
            end
        end
    end
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function TurtleApi.drop(direction, count)
    if TurtleApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("drop", direction)(count)
end

---@param side string
---@return boolean success if everything could be dumped
function TurtleApi.dump(side)
    local items = TurtleApi.getStacks()

    for slot in pairs(items) do
        TurtleApi.select(slot)
        TurtleApi.drop(side)
    end

    return TurtleApi.isEmpty()
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function TurtleApi.suck(direction, count)
    if TurtleApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("suck", direction)(count)
end

---@param direction? string
function TurtleApi.suckAll(direction)
    while TurtleApi.suck(direction) do
    end
end

---@param inventory string
---@param slot integer
---@param quantity? integer
---@return boolean, string?
function TurtleApi.suckSlot(inventory, slot, quantity)
    local stacks = InventoryPeripheral.getStacks(inventory)
    local stack = stacks[slot]

    if not stack then
        return false
    end

    quantity = math.min(quantity or stack.count, stack.count)

    if InventoryPeripheral.getFirstOccupiedSlot(inventory) == slot then
        return TurtleApi.suck(inventory, quantity)
    end

    if stacks[1] == nil then
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return TurtleApi.suck(inventory, quantity)
    end

    local firstEmptySlot = Utils.firstEmptySlot(stacks, InventoryPeripheral.getSize(inventory))

    if firstEmptySlot then
        InventoryPeripheral.move(inventory, 1, firstEmptySlot)
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return TurtleApi.suck(inventory, quantity)
    elseif TurtleApi.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    else
        local initialSlot = TurtleApi.getSelectedSlot()
        TurtleApi.selectFirstEmpty()
        TurtleApi.suck(inventory)
        InventoryPeripheral.move(inventory, slot, 1)
        TurtleApi.drop(inventory)
        os.sleep(.25) -- [todo] move to suck()
        TurtleApi.select(initialSlot)

        return TurtleApi.suck(inventory, quantity)
    end
end

---@param inventory string
---@param item string
---@param quantity integer
---@return boolean success
function TurtleApi.suckItem(inventory, item, quantity)
    local open = quantity

    while open > 0 do
        -- we want to get refreshed stacks every iteration as suckSlot() manipulates the inventory state
        local stacks = InventoryPeripheral.getStacks(inventory)
        local found = false

        for slot, stack in pairs(stacks) do
            if stack.name == item then
                if not TurtleApi.suckSlot(inventory, slot, math.min(open, stack.count)) then
                    return false
                end

                found = true
                open = open - stack.count

                if open <= 0 then
                    break
                end
            end
        end

        if not found then
            return false
        end
    end

    return true
end

---@param from string
---@param to string
---@param keep? ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function TurtleApi.pushOutput(from, to, keep)
    keep = keep or {}
    local bufferStock = InventoryApi.getStock({from}, "buffer")
    local outputStock = InventoryApi.getStock({to}, "output")
    ---@type ItemStock
    local stock = {}

    for item in pairs(outputStock) do
        if bufferStock[item] then
            stock[item] = math.max(0, bufferStock[item] - (keep[item] or 0))
        end
    end

    return InventoryApi.transfer({from}, {to}, stock, {fromTag = "buffer"})
end

---@param from string
---@param to string
function TurtleApi.pushAllOutput(from, to)
    local logged = false

    while not TurtleApi.pushOutput(from, to) do
        if not logged then
            print("[busy] output full, waiting...")
            logged = true
        end

        os.sleep(7)
    end
end

---@param from string
---@param to string
---@param transferredOutput? ItemStock
---@param max? ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function TurtleApi.pullInput(from, to, transferredOutput, max)
    local fromMaxInputStock = InventoryApi.getMaxStock({from}, "input")
    local fromMaxOutputStock = InventoryApi.getMaxStock({from}, "output")
    local toStock = InventoryApi.getStock({to}, "buffer")
    transferredOutput = transferredOutput or {}
    max = max or {}

    ---@type ItemStock
    local items = {}

    for item, maxInputStock in pairs(fromMaxInputStock) do
        if max[item] then
            maxInputStock = math.min(maxInputStock, max[item])
        end

        local inputInToStock = toStock[item] or 0

        if fromMaxOutputStock[item] and toStock[item] then
            -- in case the chest we're pulling from has the same item in input as it does in output,
            -- we need to make sure to not pull more input than is allowed by checking what parts of
            -- the "to" chest are output stock.
            inputInToStock = (inputInToStock + (transferredOutput[item] or 0)) - fromMaxOutputStock[item]
        end

        items[item] = math.min(maxInputStock - inputInToStock, InventoryApi.getItemCount({from}, item, "input"))
    end

    return InventoryApi.transfer({from}, {to}, items, {fromTag = "input", toTag = "buffer"})
end

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = TurtleApi.getStack(slot)

            if item and item.name ~= "minecraft:shulker_box" then
                return slot
            end
        end
    end
end

---@param shulker integer
---@param item string
---@return boolean
local function loadFromShulker(shulker, item)
    TurtleApi.select(shulker)
    local placedSide = TurtleApi.placeShulker()

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = InventoryPeripheral.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            TurtleApi.suckSlot(placedSide, stackSlot)
            local emptySlot = TurtleApi.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                TurtleApi.select(slotToPutIntoShulker)
                TurtleApi.drop(placedSide)
                TurtleApi.select(shulker)
            end

            TurtleApi.digShulker(placedSide)

            return true
        end
    end

    TurtleApi.digShulker(placedSide)

    return false
end

---@param name string
---@return false|integer
function TurtleApi.selectItem(name)
    if TurtleApi.isSimulating() then
        return false
    end

    local slot = TurtleApi.find(name, true)

    if not slot then
        -- [todo] why not "for slot = 1, TurtleApi.size() do ..."?
        local nextShulkerSlot = 1

        while true do
            local shulker = TurtleApi.find("minecraft:shulker_box", true, nextShulkerSlot)

            if not shulker then
                break
            end

            if loadFromShulker(shulker, name) then
                -- [note] we can return "shulker" here because the item loaded from the shulker box ends
                -- up in the slot the shulker originally was
                return shulker
            end

            nextShulkerSlot = nextShulkerSlot + 1
        end

        return false
    end

    TurtleApi.select(slot)

    return slot
end

---@param direction string
---@return boolean unloadedAll
local function loadIntoShulker(direction)
    local unloadedAll = true

    for slot = 1, TurtleApi.size() do
        local stack = TurtleApi.getStack(slot)

        if stack and not stack.name == "minecraft:shulker_box" and not stack.name == "computercraft:disk_drive" then
            TurtleApi.select(slot)

            if not TurtleApi.drop(direction) then
                unloadedAll = false
            end
        end
    end

    return unloadedAll
end

---@return boolean unloadedAll
function TurtleApi.tryLoadShulkers()
    ---@type string?
    local placedSide = nil

    for slot = 1, TurtleApi.size() do
        local stack = TurtleApi.getStack(slot)

        if stack and stack.name == "minecraft:shulker_box" then
            TurtleApi.select(slot)
            placedSide = TurtleApi.placeShulker()
            local unloadedAll = loadIntoShulker(placedSide)
            TurtleApi.select(slot)
            TurtleApi.digShulker(placedSide)

            if unloadedAll then
                return true
            end
        end
    end

    return false
end

function TurtleApi.locate()
    local x, y, z = gps.locate()

    if not x then
        error("no gps available")
    end

    TurtleApi.setPosition(Vector.create(x, y, z))

    return TurtleApi.getPosition()
end

---@param position Vector
local function stepOut(position)
    TurtleApi.refuelTo(2)

    if not TurtleApi.tryWalk("forward") then
        return false
    end

    local now = TurtleApi.locate()
    TurtleApi.setFacing(Cardinal.fromVector(Vector.minus(now, position)))

    while not TurtleApi.tryWalk("back") do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
---@param directions? MoveOrientationSide[]
---@return boolean
local function orientateSameLayer(position, directions)
    if stepOut(position) then
        return true
    end

    TurtleApi.turn("left")

    if stepOut(position) then
        TurtleApi.turn("right")
        return true
    end

    TurtleApi.turn("left")

    if stepOut(position) then
        TurtleApi.turn("back")
        return true
    end

    TurtleApi.turn("left")

    if stepOut(position) then
        TurtleApi.turn("left")
        return true
    end

    return false
end

local function addCleanupPlaceDirections(directions)
end

---@param directions? DiskDriveOrientationSide[]
---@return integer
local function orientateUsingDiskDrive(directions)
    if directions then
        for i = 1, #directions do
            if directions[i] ~= "top" and directions[i] ~= "bottom" then
                error(string.format("invalid disk-drive orientation direction: %s", directions[i]))
            end
        end
    end

    directions = directions or {"top", "bottom"}

    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.diskDriveSides = directions
    DatabaseApi.saveSquirtleDiskState(diskState)
    local placedSide = TurtleApi.tryPutAtOneOf(directions, "computercraft:disk_drive")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.diskDriveSides = {}
        diskState.cleanupSides[placedSide] = "computercraft:disk_drive"
        DatabaseApi.saveSquirtleDiskState(diskState)
    end

    -- while not SquirtleComplexApi.selectItem("computercraft:disk_drive") do
    --     SquirtleComplexApi.requireItems({["computercraft:disk_drive"] = 1})
    -- end

    -- -- [todo] should use tryPut() instead (which will also call requireItems())
    -- -- problem with that though is that tryPut() also mines, but I'd like to first
    -- -- try placing in all directions.
    -- local placedSide = Elemental.placeAtOneOf(directions)

    -- if not placedSide then
    --     -- [todo] should use (try?)mine() instead
    --     local dugSide = Elemental.digAtOneOf(directions)

    --     if not dugSide then
    --         error("todo: need help from player")
    --     end

    --     -- if not State.breakDirection or State.breakDirection == "front" then
    --     --     error("no space to put the disk drive")
    --     -- end

    --     -- -- [todo] should use put() instead - for that, put() needs to be pulled into at least this layer
    --     -- SquirtleComplexApi.mine(State.breakDirection)

    --     if not Basic.place(dugSide) then
    --         error("no space to put the disk drive")
    --     end

    --     placedSide = dugSide
    -- end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local diskDrive = TurtleApi.probe(placedSide, "computercraft:disk_drive")

    if not diskDrive then
        error("placed a disk-drive, but now it's gone")
    end

    if not diskDrive.state.facing then
        error("expected disk drive to have state.facing property")
    end

    local facing = Cardinal.rotateAround(Cardinal.fromName(diskDrive.state.facing))
    TurtleApi.dig(placedSide)

    diskState.diskDriveSides[placedSide] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)

    return facing
end

---@param method? OrientationMethod
---@param directions? OrientationSide[]
---@return integer facing
function TurtleApi.orientate(method, directions)
    method = method or TurtleApi.getOrientationMethod()

    if method == "disk-drive" then
        TurtleApi.setFacing(orientateUsingDiskDrive(directions))
    else
        local position = TurtleApi.locate()

        if not orientateSameLayer(position, directions) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return TurtleApi.getFacing()
end

---@param side string
function TurtleApi.digShulker(side)
    -- [todo] assert that there is a shulker?
    TurtleApi.dig(side)
    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.shulkerSides = {}
    diskState.cleanupSides[side] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)
end

---@return string
function TurtleApi.placeShulker()
    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.shulkerSides = TurtleApi.getShulkerSides()
    DatabaseApi.saveSquirtleDiskState(diskState)
    local placedSide = TurtleApi.tryReplaceAtOneOf(TurtleApi.getShulkerSides(), "minecraft:shulker_box")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.shulkerSides = {}
        diskState.cleanupSides[placedSide] = "minecraft:shulker_box"
        DatabaseApi.saveSquirtleDiskState(diskState)
    end

    return placedSide
end

---@param items table<string, integer>
---@param alwaysUseShulker boolean?
function TurtleApi.requireItems(items, alwaysUseShulker)
    return requireItems(TurtleApi, items, alwaysUseShulker)
end

---@param item string
---@param quantity? integer
---@param alwaysUseShulker? boolean
function TurtleApi.requireItem(item, quantity, alwaysUseShulker)
    quantity = quantity or 1
    TurtleApi.requireItems({[item] = quantity}, alwaysUseShulker)
end

function TurtleApi.cleanup()
    local diskState = DatabaseApi.getSquirtleDiskState()

    -- [todo] what is the difference between cleanupSides & diskDriveSides/shulkerSides?
    for side, block in pairs(diskState.cleanupSides) do
        if TurtleApi.probe(side, block) then
            TurtleApi.selectEmpty()
            TurtleApi.dig(side)
        end
    end

    for i = 1, #diskState.diskDriveSides do
        local side = diskState.diskDriveSides[i]
        TurtleApi.selectEmpty()

        if TurtleApi.probe(side, "computercraft:disk_drive") then
            TurtleApi.dig(side)
            break
        end
    end

    for i = 1, #diskState.shulkerSides do
        local side = diskState.shulkerSides[i]
        TurtleApi.selectEmpty()

        if TurtleApi.probe(side, "minecraft:shulker_box") then
            TurtleApi.dig(side)
            break
        end
    end

    diskState.cleanupSides = {}
    diskState.diskDriveSides = {}
    diskState.shulkerSides = {}
    DatabaseApi.saveSquirtleDiskState(diskState)
end

function TurtleApi.recover()
    local shulkerDirections = {"top", "bottom", "front"}

    for _, direction in pairs(shulkerDirections) do
        if TurtleApi.probe(direction, "minecraft:shulker_box") then
            TurtleApi.dig(direction)
        end
    end
end

---@generic T
---@param name string
---@param args string[]
---@param start fun(args:string[], options?: TurtleResumableOptions) : T
---@param main fun(state: T) : unknown|nil
---@param resume fun(state: T) : unknown|nil
---@param finish fun(state: T) : unknown|nil
function TurtleApi.runResumable(name, args, start, main, resume, finish)
    return runResumable(TurtleApi, name, args, start, main, resume, finish)
end

return TurtleApi
