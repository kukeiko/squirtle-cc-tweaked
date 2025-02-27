local Vector = require "lib.models.vector"
local Cardinal = require "lib.models.cardinal"
local DatabaseApi = require "lib.apis.database-api"
local State = require "lib.squirtle.state"
local getNative = require "lib.squirtle.get-native"
local Elemental = require "lib.squirtle.api-layers.squirtle-elemental-api"
local Basic = require "lib.squirtle.api-layers.squirtle-basic-api"
local Advanced = require "lib.squirtle.api-layers.squirtle-advanced-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local requireItems = require "lib.squirtle.require-items"
local placeShulker = require "lib.squirtle.place-shulker"
local digShulker = require "lib.squirtle.dig-shulker"

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
            State.advancePosition(delta)
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
    Elemental.select(shulker)
    local placedSide = placeShulker()

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = InventoryPeripheral.getStacks(placedSide)

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

            digShulker(placedSide)

            return true
        end
    end

    digShulker(placedSide)

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

---@param block? string
---@return boolean
local function simulateTryPut(block)
    if block then
        if not State.results.placed[block] then
            State.results.placed[block] = 0
        end

        State.results.placed[block] = State.results.placed[block] + 1
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
function SquirtleComplexApi.tryPut(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if State.simulate then
        return simulateTryPut(block)
    end

    if block then
        while not SquirtleComplexApi.selectItem(block) do
            SquirtleComplexApi.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while Basic.tryMine(side) do
    end

    -- [todo] band-aid fix
    while turtle.attack() do
        os.sleep(1)
    end

    return native()
end

---@param side? string
---@param block? string
function SquirtleComplexApi.put(side, block)
    if State.simulate then
        return simulatePut(block)
    end

    if not SquirtleComplexApi.tryPut(side, block) then
        error("failed to place")
    end
end

---@param sides? PlaceSide[]
---@param block? string
---@return PlaceSide? placedDirection
function SquirtleComplexApi.tryPutAtOneOf(sides, block)
    if State.simulate then
        -- [todo] reconsider if this method should really be simulatable, as its outcome depends on world state
        return simulatePut(block)
    end

    sides = sides or {"top", "front", "bottom"}

    if block then
        while not SquirtleComplexApi.selectItem(block) do
            SquirtleComplexApi.requireItem(block)
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

        while Basic.tryMine(sides[i]) do
        end

        if native() then
            return sides[i]
        end
    end
end

function SquirtleComplexApi.locate()
    local x, y, z = gps.locate()

    if not x then
        error("no gps available")
    end

    Elemental.setPosition(Vector.create(x, y, z))

    return Elemental.getPosition()
end

---@param position Vector
local function stepOut(position)
    Advanced.refuelTo(2)

    if not SquirtleComplexApi.tryWalk("forward") then
        return false
    end

    local now = SquirtleComplexApi.locate()
    Elemental.setFacing(Cardinal.fromVector(Vector.minus(now, position)))

    while not SquirtleComplexApi.tryWalk("back") do
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
    local placedSide = SquirtleComplexApi.tryPutAtOneOf(directions, "computercraft:disk_drive")

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

    local diskDrive = Basic.probe(placedSide, "computercraft:disk_drive")

    if not diskDrive then
        error("placed a disk-drive, but now it's gone")
    end

    if not diskDrive.state.facing then
        error("expected disk drive to have state.facing property")
    end

    local facing = Cardinal.rotateAround(Cardinal.fromName(diskDrive.state.facing))
    Basic.dig(placedSide)

    diskState.diskDriveSides[placedSide] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)

    return facing
end

function SquirtleComplexApi.cleanup()
    local diskState = DatabaseApi.getSquirtleDiskState()

    for side, block in pairs(diskState.cleanupSides) do
        if SquirtleComplexApi.probe(side, block) then
            Basic.selectEmpty()
            SquirtleComplexApi.dig(side)
        end
    end

    for i = 1, #diskState.diskDriveSides do
        local side = diskState.diskDriveSides[i]
        Basic.selectEmpty()

        if SquirtleComplexApi.probe(side, "computercraft:disk_drive") then
            SquirtleComplexApi.dig(side)
            break
        end
    end

    for i = 1, #diskState.shulkerSides do
        local side = diskState.shulkerSides[i]
        Basic.selectEmpty()

        if SquirtleComplexApi.probe(side, "minecraft:shulker_box") then
            SquirtleComplexApi.dig(side)
            break
        end
    end

    diskState.cleanupSides = {}
    diskState.diskDriveSides = {}
    diskState.shulkerSides = {}
    DatabaseApi.saveSquirtleDiskState(diskState)
end

---@param method? OrientationMethod
---@param directions? OrientationSide[]
---@return integer facing
function SquirtleComplexApi.orientate(method, directions)
    method = method or State.orientationMethod

    if method == "disk-drive" then
        Elemental.setFacing(orientateUsingDiskDrive(directions))
    else
        local position = SquirtleComplexApi.locate()

        if not orientateSameLayer(position, directions) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return Elemental.getFacing()
end

---@param items table<string, integer>
---@param shulker? boolean
function SquirtleComplexApi.requireItems(items, shulker)
    requireItems(items, shulker)
end

---@param item string
---@param quantity? integer
---@param shulker? boolean
function SquirtleComplexApi.requireItem(item, quantity, shulker)
    quantity = quantity or 1
    SquirtleComplexApi.requireItems({[item] = quantity}, shulker)
end

---@param direction string
---@return boolean unloadedAll
local function loadIntoShulker(direction)
    local unloadedAll = true

    for slot = 1, Elemental.size() do
        local stack = Elemental.getStack(slot)

        if stack and not stack.name == "minecraft:shulker_box" and not stack.name == "computercraft:disk_drive" then
            Elemental.select(slot)

            if not Elemental.drop(direction) then
                unloadedAll = false
            end
        end
    end

    return unloadedAll
end

---@return boolean unloadedAll
function SquirtleComplexApi.tryLoadShulkers()
    ---@type string?
    local placedSide = nil

    for slot = 1, Elemental.size() do
        local stack = Elemental.getStack(slot)

        if stack and stack.name == "minecraft:shulker_box" then
            Elemental.select(slot)
            placedSide = placeShulker()
            local unloadedAll = loadIntoShulker(placedSide)
            Elemental.select(slot)
            digShulker(placedSide)

            if unloadedAll then
                return true
            end
        end
    end

    return false
end

return SquirtleComplexApi
