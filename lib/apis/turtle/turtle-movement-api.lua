local Utils = require "lib.tools.utils"
local World = require "lib.models.world"
local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local getNative = require "lib.apis.turtle.functions.get-native"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleInventoryApi = require "lib.apis.turtle.turtle-inventory-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"
local findPath = require "lib.apis.turtle.functions.find-path"

local bucket = "minecraft:bucket"
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@class TurtleMovementApi
local TurtleMovementApi = {}

---Turns 1x time towards direction "back", "left" or "right".
---If flipTurns is on, "left" will become "right" and vice versa.
---@param direction string
function TurtleMovementApi.turn(direction)
    -- [todo] use TurtleStateApi
    if direction == "back" then
        TurtleMovementApi.turn("left")
        TurtleMovementApi.turn("left")
    elseif direction == "left" or direction == "right" then
        if TurtleStateApi.getFlipTurns() then
            if direction == "left" then
                direction = "right"
            elseif direction == "right" then
                direction = "left"
            end
        end

        if TurtleStateApi.isSimulating() then
            TurtleStateApi.simulateTurn(direction)
        else
            getNative("turn", direction)()
            TurtleStateApi.setFacing(Cardinal.rotate(TurtleStateApi.getFacing(), direction))
        end
    end
end

---@param target integer
---@param current? integer
function TurtleMovementApi.face(target, current)
    current = current or TurtleStateApi.getFacing()

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        TurtleMovementApi.turn("back")
    elseif (current + 1) % 4 == target then
        TurtleMovementApi.turn("right")
    elseif (current - 1) % 4 == target then
        TurtleMovementApi.turn("left")
    end

    return target
end

---@param quantity? integer
---@return boolean, string?
function TurtleMovementApi.refuel(quantity)
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
    fuel = fuel or TurtleStateApi.missingFuel()
    local fuelStacks = pickFuelStacks(TurtleInventoryApi.getStacks(), fuel, allowLava)
    local emptyBucketSlot = TurtleInventoryApi.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        TurtleInventoryApi.select(slot)
        TurtleMovementApi.refuel(stack.count)

        local remaining = TurtleInventoryApi.getStack(slot)

        if remaining and remaining.name == bucket then
            if not emptyBucketSlot or not TurtleInventoryApi.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or TurtleStateApi.missingFuel()
    local _, y = term.getCursorPos()

    while not TurtleStateApi.hasFuel(fuel) do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - TurtleStateApi.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function TurtleMovementApi.refuelTo(fuel)
    if TurtleStateApi.hasFuel(fuel) then
        return true
    elseif fuel > TurtleStateApi.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - TurtleStateApi.getFuelLimit()))
    end

    refuelFromBackpack(fuel)

    if not TurtleStateApi.hasFuel(fuel) then
        refuelWithHelpFromPlayer(fuel)
    end
end

---@param action string
---@param direction string
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
---@param direction? string
---@param steps? integer
---@return boolean success, integer stepsTaken, string? error
function TurtleMovementApi.tryWalk(direction, steps)
    direction = direction or "forward"
    local native = getNative("go", direction)
    steps = steps or 1

    if TurtleStateApi.isSimulating() then
        -- [note] "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    end

    if not TurtleStateApi.hasFuel(steps) then
        TurtleMovementApi.refuelTo(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleStateApi.getFacing()))

    for step = 1, steps do
        local success, message = native()

        if success then
            TurtleStateApi.changePosition(delta)
        else
            return false, step - 1, message
        end
    end

    return true, steps
end

---Move towards the given direction without trying to remove any obstacles found. Will prompt for fuel if there isn't enough.
---Throws an error if it failed to move all steps.
---If simulation is active, will always throw.
---@param direction? string
---@param steps? integer
function TurtleMovementApi.walk(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleMovementApi.tryWalk(direction, steps)

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
        if TurtleStateApi.isResuming() and TurtleStateApi.fuelTargetReached() and not TurtleStateApi.facingTargetReached() then
            -- we seem to be in correct position but the facing is off, meaning that there must've been
            -- a block that caused us to turn to try and mine it. in order to resume, we'll just
            -- stop the simulation and orient the turtle so that the turning code gets run from the beginning.
            local facing = TurtleStateApi.getFacing()
            TurtleStateApi.endSimulation()
            TurtleMovementApi.face(facing)
        end

        if TurtleStateApi.isSimulating() then
            TurtleStateApi.simulateMove("back")
        else
            while not native() do
                if not didTurnBack then
                    TurtleMovementApi.turn("right")
                    TurtleMovementApi.turn("right")
                    direction = "forward"
                    native = getNative("go", "forward")
                    didTurnBack = true
                end

                while TurtleMiningApi.tryMine(direction) do
                end

                local block = TurtleMiningApi.probe(direction)

                if block and not TurtleStateApi.canBreak(block) then
                    TurtleMovementApi.turn("left")
                    TurtleMovementApi.turn("left")

                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end
        end
    end

    if didTurnBack then
        TurtleMovementApi.turn("left")
        TurtleMovementApi.turn("left")
    end

    return true, steps
end

---[todo] tryMove() should throw an error if called directly when simulating. since move() can be called while simulating,
---i'll need to move the function body out so move() can still call it.
---@param direction string?
---@param steps integer?
---@return boolean, integer, string?
function TurtleMovementApi.tryMove(direction, steps)
    if direction == "back" then
        return tryMoveBack(steps)
    end

    direction = direction or "forward"
    steps = steps or 1
    local native = getNative("go", direction)
    local delta = Cardinal.toVector(Cardinal.fromSide(direction, TurtleStateApi.getFacing()))

    for step = 1, steps do
        if TurtleStateApi.isSimulating() then
            TurtleStateApi.simulateMove(direction)
        else
            while not native() do
                while TurtleMiningApi.tryMine(direction) do
                end

                local block = TurtleMiningApi.probe(direction)

                if block and not TurtleStateApi.canBreak(block) then
                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            TurtleStateApi.changePosition(delta)
        end
    end

    return true, steps
end

---@param direction? string
---@param steps? integer
function TurtleMovementApi.move(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = TurtleMovementApi.tryMove(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("move", direction, steps, stepsTaken, message))
end

---@param target Vector
---@return boolean, string?
function TurtleMovementApi.tryMoveToPoint(target)
    local delta = Vector.minus(target, TurtleStateApi.getPosition())

    if delta.y > 0 then
        if not TurtleMovementApi.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not TurtleMovementApi.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        TurtleMovementApi.face(Cardinal.east)
        if not TurtleMovementApi.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        TurtleMovementApi.face(Cardinal.west)
        if not TurtleMovementApi.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        TurtleMovementApi.face(Cardinal.south)

        if not TurtleMovementApi.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        TurtleMovementApi.face(Cardinal.north)

        if not TurtleMovementApi.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function movePath(path)
    for i, next in ipairs(path) do
        local success, failedSide = TurtleMovementApi.tryMoveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function TurtleMovementApi.navigate(to, world, breakable)
    breakable = breakable or function()
        return false
    end

    local restoreBreakable = TurtleStateApi.setBreakable(breakable)

    if not world then
        local position = TurtleStateApi.getPosition()
        world = World.create(position.x, position.y, position.z)
    end

    local from = TurtleStateApi.getPosition()
    local facing = TurtleStateApi.getFacing()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            restoreBreakable()
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        TurtleMovementApi.refuelTo(distance)
        local success, failedSide = movePath(path)

        if success then
            restoreBreakable()
            return true
        elseif failedSide then
            from = TurtleStateApi.getPosition()
            facing = TurtleStateApi.getFacing()
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))
            World.setBlock(world, scannedLocation)
        end
    end
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function TurtleMovementApi.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if TurtleMovementApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and TurtleMovementApi.tryWalk("up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and TurtleMovementApi.tryWalk("down") then
            strategy = "down"
            forbidden = "up"
        elseif TurtleMovementApi.turn("left") and TurtleMovementApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleMovementApi.turn("left") and forbidden ~= "back" and TurtleMovementApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif TurtleMovementApi.turn("left") and TurtleMovementApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while TurtleMovementApi.tryWalk("forward") do
            end
        elseif strategy == "up" then
            while TurtleMovementApi.tryWalk("up") do
            end
        elseif strategy == "down" then
            while TurtleMovementApi.tryWalk("down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

return TurtleMovementApi
