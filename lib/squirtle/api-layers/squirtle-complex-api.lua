local Vector = require "lib.common.vector"
local Cardinal = require "lib.common.cardinal"
local State = require "lib.squirtle.state"
local getNative = require "lib.squirtle.get-native"
local Elemental = require "lib.squirtle.api-layers.squirtle-elemental-api"
local Basic = require "lib.squirtle.api-layers.squirtle-basic-api"
local Advanced = require "lib.squirtle.api-layers.squirtle-advanced-api"
local Inventory = require "lib.inventory.inventory-api"
local requireItems = require "lib.squirtle.require-items"

---The complex layer starts having movement functionality.
---@class SquirtleComplexApi : SquirtleAdvancedApi
local SquirtleComplexApi = {}
setmetatable(SquirtleComplexApi, {__index = Advanced})

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

---@param direction? string
---@param steps? integer
---@return boolean, integer, string?
function SquirtleComplexApi.tryWalk(direction, steps)
    direction = direction or "forward"
    local native = getNative("go", direction)
    steps = steps or 1

    if State.simulate then
        -- [note] "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    end

    if not Basic.hasFuel(steps) then
        Advanced.refuelTo(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(direction, Elemental.getFacing()))

    for step = 1, steps do
        local success, message = native()

        if success then
            Elemental.changePosition(delta)
        else
            return false, step - 1, message
        end
    end

    return true, steps
end

---@param direction? string
---@param steps? integer
function SquirtleComplexApi.walk(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = SquirtleComplexApi.tryWalk(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("walk", direction, steps, stepsTaken, message))
end

---@param steps integer?
---@return boolean, integer, string?
local function tryMoveBack(steps)
    steps = steps or 1
    local native = getNative("go", "back")
    local didTurnBack = false

    for step = 1, steps do
        if State.isResuming() and not State.facingTargetReached() and State.fuelTargetReached() then
            -- we seem to be in correct position but the facing is off, meaning that there must've been
            -- a block that caused us to turn to try and mine it. in order to resume, we'll just
            -- stop the simulation and orient the turtle towards the initial state, so that the
            -- turning code gets run from start.
            State.simulate = false
            Basic.face(State.simulation.current.facing)
        end

        if State.simulate then
            State.advanceFuel()
        else
            while not native() do
                if not didTurnBack then
                    Basic.turn("right")
                    Basic.turn("right")
                    direction = "forward"
                    native = getNative("go", "forward")
                    didTurnBack = true
                end

                while Basic.tryMine(direction) do
                end

                local block = Basic.probe(direction)

                if block and not State.canBreak(block) then
                    Basic.turn("left")
                    Basic.turn("left")

                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end
        end
    end

    if didTurnBack then
        Basic.turn("left")
        Basic.turn("left")
    end

    return true, steps
end

---@param direction string?
---@param steps integer?
---@return boolean, integer, string?
function SquirtleComplexApi.tryMove(direction, steps)
    if direction == "back" then
        return tryMoveBack(steps)
    end

    direction = direction or "forward"
    steps = steps or 1
    local native = getNative("go", direction)
    local delta = Cardinal.toVector(Cardinal.fromSide(direction, Elemental.getFacing()))

    for step = 1, steps do
        if State.simulate then
            State.advanceFuel()
        else
            while not native() do
                while Basic.tryMine(direction) do
                end

                local block = Basic.probe(direction)

                if block and not State.canBreak(block) then
                    return false, step - 1, string.format("blocked by %s", block.name)
                end
            end

            Elemental.changePosition(delta)
        end
    end

    return true, steps
end

---@param direction? string
---@param steps? integer
function SquirtleComplexApi.move(direction, steps)
    direction = direction or "forward"
    steps = steps or 1
    local success, stepsTaken, message = SquirtleComplexApi.tryMove(direction, steps)

    if success then
        return nil
    end

    error(getGoErrorMessage("move", direction, steps, stepsTaken, message))
end

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = Basic.getStack(slot)

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
    Basic.select(shulker)

    local placedSide = Basic.placeFrontTopOrBottom()

    if not placedSide then
        if not State.breakDirection then
            return false
        end

        SquirtleComplexApi.mine(State.breakDirection)
        placedSide = Basic.placeFrontTopOrBottom()

        if not placedSide then
            return false
        end
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = Inventory.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            Advanced.suckSlot(placedSide, stackSlot)
            local emptySlot = Basic.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                Basic.select(slotToPutIntoShulker)
                Elemental.drop(placedSide)
                Basic.select(shulker)
            end

            Elemental.dig(placedSide)

            return true
        end
    end

    Elemental.dig(placedSide)

    return false
end

---@param name string
---@return false|integer
function SquirtleComplexApi.selectItem(name)
    if State.simulate then
        return false
    end

    local slot = Basic.find(name, true)

    if not slot then
        local nextShulkerSlot = 1

        while true do
            local shulker = Basic.find("minecraft:shulker_box", true, nextShulkerSlot)

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

    Elemental.select(slot)

    return slot
end

---@param refresh? boolean
function SquirtleComplexApi.locate(refresh)
    if refresh then
        local x, y, z = gps.locate()

        if not x then
            error("no gps available")
        end

        Elemental.setPosition(Vector.create(x, y, z))
    end

    return Elemental.getPosition()
end

---@param position Vector
local function stepOut(position)
    Advanced.refuelTo(2)

    if not SquirtleComplexApi.tryWalk("forward") then
        return false
    end

    local now = SquirtleComplexApi.locate(true)
    Elemental.setFacing(Cardinal.fromVector(Vector.minus(now, position)))

    while not SquirtleComplexApi.tryWalk("back") do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
---@return boolean
local function orientateSameLayer(position)
    if stepOut(position) then
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("right")
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("back")
        return true
    end

    Basic.turn("left")

    if stepOut(position) then
        Basic.turn("left")
        return true
    end

    return false
end

---@return integer
local function orientateUsingDiskDrive()
    while not SquirtleComplexApi.selectItem("computercraft:disk_drive") do
        SquirtleComplexApi.requireItems({["computercraft:disk_drive"] = 1})
    end

    local placedSide = Basic.placeTopOrBottom()

    if not placedSide then
        if not State.breakDirection or State.breakDirection == "front" then
            error("no space to put the disk drive")
        end

        -- [todo] should use put() instead - for that, put() needs to be pulled into at least this layer
        SquirtleComplexApi.mine(State.breakDirection)

        if not Basic.place(State.breakDirection) then
            error("no space to put the disk drive")
        end

        placedSide = State.breakDirection
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local diskDrive = Basic.probe(placedSide, "computercraft:disk_drive")

    if not diskDrive then
        error("placed a disk-drive, but now it's gone")
    end

    if not diskDrive.state.facing then
        error("expected disk drive to have state.facing property")
    end

    local facing = Cardinal.rotateAround(Cardinal.fromName(diskDrive.state.facing))
    Basic.dig(placedSide)

    return facing
end

---@param refresh? boolean
---@return Vector position, integer facing
function SquirtleComplexApi.orientate(refresh)
    if State.orientationMethod == "disk-drive" then
        if refresh then
            Elemental.setFacing(orientateUsingDiskDrive())
        end
    else
        local position = SquirtleComplexApi.locate(refresh)
        local facing = Elemental.getFacing()

        if refresh or not facing then
            if not orientateSameLayer(position) then
                error("failed to orientate. possibly blocked in.")
            end
        end
    end

    return Elemental.getPosition(), Elemental.getFacing()
end

---@param items table<string, integer>
---@param shulker boolean?
function SquirtleComplexApi.requireItems(items, shulker)
    requireItems(items, shulker)
end

return SquirtleComplexApi
