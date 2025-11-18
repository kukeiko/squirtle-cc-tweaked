local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"
local PeripheralApi = require "lib.common.peripheral-api"
local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local InventoryApi = require "lib.inventory.inventory-api"
local StorageService = require "lib.inventory.storage-service"
local TurtleInventoryService = require "lib.turtle.turtle-inventory-service"
local TurtleStateApi = require "lib.turtle.api-parts.turtle-state-api"
local TurtleMovementApi = require "lib.turtle.api-parts.turtle-movement-api"
local TurtleInventoryApi = require "lib.turtle.api-parts.turtle-inventory-api"
local TurtleShulkerApi = require "lib.turtle.api-parts.turtle-shulker-api"
local TurtleRefuelApi = require "lib.turtle.api-parts.turtle-refuel-api"
local DatabaseApi = require "lib.database.database-api"
local getNative = require "lib.turtle.functions.get-native"
local digArea = require "lib.turtle.functions.dig-area"
local buildFloor = require "lib.turtle.functions.build-floor"
local harvestBirchTree = require "lib.turtle.functions.harvest-birch-tree"
local requireItems = require "lib.turtle.functions.require-items"

---@alias OrientationMethod "move" | "disk-drive"
---@alias DiskDriveOrientationSide "top" | "bottom"
---@alias MoveOrientationSide "front" | "back" | "left" | "right"
---@alias OrientationSide DiskDriveOrientationSide | MoveOrientationSide

local defaultItemMaxCount = 64
local maxCarriedShulkers = 8

---@class TurtleApi
local TurtleApi = {}

local function assertNotSimulating(fnName)
    if TurtleApi.isSimulating() then
        error(string.format("%s() does not support simulation", fnName))
    end
end

---@return integer
function TurtleApi.getFacing()
    return TurtleStateApi.getFacing()
end

---@param side string
---@return integer
function TurtleApi.getFacingTowards(side)
    return TurtleStateApi.getFacingTowards(side)
end

---@param facing integer
function TurtleApi.setFacing(facing)
    TurtleStateApi.setFacing(facing)
end

---@return Vector
function TurtleApi.getPosition()
    return TurtleStateApi.getPosition()
end

---@return Vector?
function TurtleApi.tryGetLivePosition()
    local x, y, z = gps.locate()

    if not x then
        return nil
    end

    return Vector.create(x, y, z)
end

---@param direction string
---@return Vector
function TurtleApi.getPositionTowards(direction)
    return TurtleStateApi.getPositionTowards(direction)
end

---@param position Vector
function TurtleApi.setPosition(position)
    TurtleStateApi.setPosition(position)
end

---@class TurtleConfigurationOptions
---@field orientate OrientationMethod?
---@field shulkerSides PlaceSide[]?
---@param options TurtleConfigurationOptions
function TurtleApi.configure(options)
    if options.orientate then
        TurtleStateApi.setOrientationMethod(options.orientate)
    end

    if options.shulkerSides then
        TurtleStateApi.setShulkerSides(options.shulkerSides)
    end
end

---@param block Block
---@return boolean
function TurtleApi.canBreak(block)
    return TurtleStateApi.canBreak(block)
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function TurtleApi.setBreakable(predicate)
    return TurtleStateApi.setBreakable(predicate)
end

---@param flipTurns boolean
function TurtleApi.setFlipTurns(flipTurns)
    TurtleStateApi.setFlipTurns(flipTurns)
end

---@return boolean
function TurtleApi.getFlipTurns()
    return TurtleStateApi.getFlipTurns()
end

---@return OrientationMethod
function TurtleApi.getOrientationMethod()
    return TurtleStateApi.getOrientationMethod()
end

---@return integer | "unlimited"
function TurtleApi.getFuelLevel()
    return TurtleStateApi.getFuelLevel()
end

---@return integer
function TurtleApi.getFiniteFuelLevel()
    return TurtleStateApi.getFiniteFuelLevel()
end

---@return integer | "unlimited"
function TurtleApi.getFuelLimit()
    return TurtleStateApi.getFuelLimit()
end

---@return integer
function TurtleApi.getFiniteFuelLimit()
    return TurtleStateApi.getFiniteFuelLimit()
end

---@param fuel integer
---@return boolean
function TurtleApi.hasFuel(fuel)
    return TurtleStateApi.hasFuel(fuel)
end

---@param limit? integer
---@return integer
function TurtleApi.missingFuel(limit)
    return TurtleStateApi.missingFuel(limit)
end

function TurtleApi.isSimulating()
    return TurtleStateApi.isSimulating()
end

---@return boolean
function TurtleApi.isResuming()
    return TurtleStateApi.isResuming()
end

function TurtleApi.endResume()
    TurtleStateApi.endResume()
end

---@return boolean
function TurtleApi.checkResumeEnd()
    return TurtleStateApi.checkResumeEnd()
end

---@param fn fun() : nil
---@return SimulationResults
function TurtleApi.simulate(fn)
    return TurtleStateApi.simulate(fn)
end

---@param fuel integer
---@param facing integer
---@param position Vector
function TurtleApi.resume(fuel, facing, position)
    TurtleStateApi.resume(fuel, facing, position)
end

---@param block string
---@param quantity? integer
function TurtleApi.recordPlacedBlock(block, quantity)
    TurtleStateApi.recordPlacedBlock(block, quantity)
end

---@param block string
---@param quantity? integer
function TurtleApi.recordTakenBlock(block, quantity)
    TurtleStateApi.recordTakenBlock(block, quantity)
end

---Turns 1x time towards direction "back", "left" or "right".
---If flipTurns is on, "left" will become "right" and vice versa.
---@param direction string
function TurtleApi.turn(direction)
    TurtleMovementApi.turn(direction)
end

function TurtleApi.left()
    TurtleApi.turn("left")
end

function TurtleApi.right()
    TurtleApi.turn("right")
end

function TurtleApi.around()
    TurtleApi.turn("back")
end

---@param direction "left" | "right"
function TurtleApi.strafe(direction)
    TurtleMovementApi.strafe(TurtleApi, direction)
end

---@param target integer
function TurtleApi.face(target)
    return TurtleMovementApi.face(target)
end

---@param quantity? integer
---@return boolean, string?
function TurtleApi.refuel(quantity)
    return turtle.refuel(quantity)
end

---@param fuel integer
---@param barrel string?
---@param ioChest string?
function TurtleApi.refuelTo(fuel, barrel, ioChest)
    TurtleRefuelApi.refuelTo(TurtleApi, fuel, barrel, ioChest)
end

---Move towards the given direction without trying to remove any obstacles found. Will prompt for fuel if there isn't enough.
---If simulation is active, will always return false with 0 steps taken.
---@param direction? MoveDirection
---@param steps? integer
---@return boolean success, integer stepsTaken, string? error
function TurtleApi.tryWalk(direction, steps)
    return TurtleMovementApi.tryWalk(TurtleApi, direction, steps)
end

---Move towards the given direction without trying to remove any obstacles found. Will prompt for fuel if there isn't enough.
---Throws an error if it failed to move all steps.
---If simulation is active, will always throw.
---@param direction? MoveDirection
---@param steps? integer
function TurtleApi.walk(direction, steps)
    TurtleMovementApi.walk(TurtleApi, direction, steps)
end

---@param direction MoveDirection?
---@param steps integer?
---@return boolean, integer, string?
function TurtleApi.tryMove(direction, steps)
    return TurtleMovementApi.tryMove(TurtleApi, direction, steps)
end

---@param direction? MoveDirection
---@param steps? integer
function TurtleApi.move(direction, steps)
    TurtleMovementApi.move(TurtleApi, direction, steps)
end

---@param steps? integer
function TurtleApi.up(steps)
    TurtleApi.move("up", steps)
end

---@param steps? integer
function TurtleApi.forward(steps)
    TurtleApi.move("forward", steps)
end

---@param steps? integer
function TurtleApi.down(steps)
    TurtleApi.move("down", steps)
end

---@param steps? integer
function TurtleApi.back(steps)
    TurtleApi.move("back", steps)
end

---@param target Vector
---@return boolean, string?
function TurtleApi.tryMoveToPoint(target)
    return TurtleMovementApi.tryMoveToPoint(TurtleApi, target)
end

---@param target Vector
function TurtleApi.moveToPoint(target)
    TurtleMovementApi.moveToPoint(TurtleApi, target)
end

---@param to Vector
---@param world? World
---@param breakable? function
function TurtleApi.navigate(to, world, breakable)
    return TurtleMovementApi.navigate(TurtleApi, to, world, breakable)
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function TurtleApi.navigateTunnel(checkEarlyExit)
    return TurtleMovementApi.navigateTunnel(TurtleApi, checkEarlyExit)
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

---@param side string
function TurtleApi.isWiredModemPowered(side)
    local modem = TurtleApi.probe(side, ItemApi.wiredModem)

    if not modem then
        error(string.format("there is no modem @ %s", side))
    end

    return modem.state.peripheral == true
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

---@param depth integer
---@param width integer
---@param block string
function TurtleApi.buildFloor(depth, width, block)
    return buildFloor(TurtleApi, depth, width, block)
end

---@param depth integer
---@param width integer
---@param block string
function TurtleApi.buildCeiling(depth, width, block)
    return buildFloor(TurtleApi, depth, width, block, true)
end

---@param minSaplings? integer
function TurtleApi.harvestBirchTree(minSaplings)
    harvestBirchTree(TurtleApi, minSaplings)
end

---@param direction? string
---@param item? string
---@param require? boolean
---@return boolean, string?
function TurtleApi.use(direction, item, require)
    if TurtleApi.isSimulating() then
        return true
    end

    if item then
        if not TurtleApi.selectItem(item) and not require then
            return false
        end

        while not TurtleApi.selectItem(item) do
            TurtleApi.requireItem(item, 1)
        end
    end

    direction = direction or "front"
    return getNative("place", direction)()
end

---@param direction? string
---@param text? string
---@return boolean, string?
function TurtleApi.place(direction, text)
    if TurtleApi.isSimulating() then
        return true
    end

    if TurtleApi.probe(direction) then
        return false
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

---@param block? string
---@return boolean
local function simulateTryPut(block)
    if block then
        TurtleApi.recordPlacedBlock(block)
    end

    return true
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
            TurtleApi.requireItem(block, 1)
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
        simulateTryPut(block)
    elseif not TurtleApi.tryPut(side, block) then
        error("failed to place")
    end
end

---@param block? string
function TurtleApi.above(block)
    TurtleApi.put("top", block)
end

---@param block? string
function TurtleApi.ahead(block)
    TurtleApi.put("front", block)
end

---@param block? string
function TurtleApi.below(block)
    TurtleApi.put("bottom", block)
end

---@param sides? PlaceSide[]
---@param block? string
---@return PlaceSide? placedDirection
function TurtleApi.tryPutAtOneOf(sides, block)
    if TurtleApi.isSimulating() then
        -- [todo] reconsider if this method should really be simulatable, as its outcome depends on world state
        simulateTryPut(block)
        return
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

---@param side PlaceSide?
function TurtleApi.placeWater(side)
    if TurtleApi.isSimulating() then
        TurtleStateApi.placeWater()
        return
    elseif TurtleApi.probe(side, "minecraft:water") then
        return
    end

    if not TurtleApi.use(side, ItemApi.waterBucket) then
        error("failed to place water")
    end
end

---@param side PlaceSide?
function TurtleApi.tryTakeWater(side)
    if TurtleApi.isSimulating() then
        TurtleStateApi.takeWater()
        return true
    end

    return TurtleApi.use(side, ItemApi.bucket)
end

---@param side PlaceSide?
function TurtleApi.takeWater(side)
    if not TurtleApi.tryTakeWater(side) then
        error("failed to take water")
    end
end

---@param side PlaceSide?
function TurtleApi.placeLava(side)
    if TurtleApi.isSimulating() then
        TurtleStateApi.placeLava()
        return
    elseif TurtleApi.probe(side, "minecraft:lava") then
        return
    end

    if not TurtleApi.use(side, ItemApi.lavaBucket) then
        error("failed to place lava")
    end
end

---@param side PlaceSide?
function TurtleApi.tryTakeLava(side)
    if TurtleApi.isSimulating() then
        TurtleStateApi.takeLava()
        return true
    end

    return TurtleApi.use(side, ItemApi.bucket)
end

---@param side PlaceSide?
function TurtleApi.takeLava(side)
    if not TurtleApi.tryTakeLava(side) then
        error("failed to take Lava")
    end
end

---@return integer
function TurtleApi.size()
    return TurtleInventoryApi.size()
end

---@param slot? integer
---@return integer
function TurtleApi.getItemCount(slot)
    return TurtleInventoryApi.getItemCount(slot)
end

---@param slot? integer
---@return integer
function TurtleApi.getItemSpace(slot)
    return TurtleInventoryApi.getItemSpace(slot)
end

---@return integer
function TurtleApi.getSelectedSlot()
    return TurtleInventoryApi.getSelectedSlot()
end

---@param slot integer
---@return boolean
function TurtleApi.select(slot)
    return TurtleInventoryApi.select(TurtleApi, slot)
end

---@param slot? integer
---@param detailed? boolean
---@return ItemStack?
function TurtleApi.getStack(slot, detailed)
    return TurtleInventoryApi.getStack(slot, detailed)
end

---@param slot integer
---@param quantity? integer
---@return boolean
function TurtleApi.transferTo(slot, quantity)
    return TurtleInventoryApi.transferTo(slot, quantity)
end

---@param slot integer
---@return boolean
function TurtleApi.selectIfNotEmpty(slot)
    return TurtleInventoryApi.selectIfNotEmpty(TurtleApi, slot)
end

---@param startAt? number
---@return integer
function TurtleApi.selectEmpty(startAt)
    return TurtleInventoryApi.selectEmpty(TurtleApi, startAt)
end

---@return integer
function TurtleApi.selectFirstEmpty()
    return TurtleInventoryApi.selectFirstEmpty(TurtleApi)
end

---@param startAt? number
function TurtleApi.firstEmptySlot(startAt)
    return TurtleInventoryApi.firstEmptySlot(startAt)
end

---@return integer
function TurtleApi.numEmptySlots()
    return TurtleInventoryApi.numEmptySlots()
end

---@return boolean
function TurtleApi.isFull()
    return TurtleInventoryApi.isFull()
end

---@return boolean
function TurtleApi.isEmpty()
    return TurtleInventoryApi.isEmpty()
end

---@param detailed? boolean
---@return ItemStack[]
function TurtleApi.getStacks(detailed)
    return TurtleInventoryApi.getStacks(detailed)
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function TurtleApi.getItemStock(predicate)
    return TurtleInventoryApi.getItemStock(predicate)
end

---@param includeShulkers? boolean
---@return table<string, integer>
function TurtleApi.getStock(includeShulkers)
    return TurtleInventoryApi.getStock(TurtleApi, includeShulkers)
end

---@return ItemStock
function TurtleApi.getShulkerStock()
    return TurtleShulkerApi.getShulkerStock(TurtleApi)
end

---@param name string
---@param nbt? string
---@return integer?
function TurtleApi.find(name, nbt)
    return TurtleInventoryApi.find(name, nbt)
end

---@param item string
---@param minCount? integer
---@return boolean
function TurtleApi.has(item, minCount)
    return TurtleInventoryApi.has(item, minCount)
end

---Condenses the inventory by stacking matching items.
function TurtleApi.condense()
    TurtleInventoryApi.condense(TurtleApi)
end

---@param side? string
---@return boolean
function TurtleApi.compare(side)
    return getNative("compare", side or "forward")()
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
---@param items? string[]
---@return boolean success if everything could be dumped
function TurtleApi.tryDump(side, items)
    local stacks = TurtleApi.getStacks()

    for slot, stack in pairs(stacks) do
        if not items or Utils.contains(items, stack.name) then
            TurtleApi.select(slot)
            TurtleApi.drop(side)
        end
    end

    if items then
        local stock = TurtleApi.getStock()

        for item in pairs(items) do
            if stock[item] then
                return false
            end
        end

        return true
    else
        return TurtleApi.isEmpty()
    end
end

---@param side string
---@param items? string[]
function TurtleApi.dump(side, items)
    if not TurtleApi.tryDump(side, items) then
        error("failed to empty out inventory")
    end
end

---@param stash string
function TurtleApi.drainStashDropper(stash)
    repeat
        local totalItemStock = InventoryApi.getTotalItemCount({stash}, "buffer")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until InventoryApi.getTotalItemCount({stash}, "buffer") == totalItemStock
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
---@param ignoreIfFull? string[]
---@return boolean success, ItemStock transferred, ItemStock open
function TurtleApi.pushOutput(from, to, keep, ignoreIfFull)
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

    local transferredAll, transferred, open = InventoryApi.transfer({from}, {to}, stock, {fromTag = "buffer", toTag = "output"})

    if transferredAll or not ignoreIfFull then
        return transferredAll, transferred, open
    else
        local openIgnored = Utils.copy(open)

        for _, item in pairs(ignoreIfFull) do
            openIgnored[item] = nil
        end

        return Utils.isEmpty(openIgnored), transferred, open
    end
end

---@param from string
---@param to string
---@param keep? ItemStock
---@param ignoreIfFull? string[]
function TurtleApi.pushAllOutput(from, to, keep, ignoreIfFull)
    local logged = false

    while not TurtleApi.pushOutput(from, to, keep, ignoreIfFull) do
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

---@class TurtleDoHomeworkOptions
---@field barrel string
---@field ioChest string
---@field minFuel integer
---@field drainDropper string?
---@field input TurtleDoHomeworkInputOptions?
---@field output TurtleDoHomeworkOutputOptions?
---@class TurtleDoHomeworkInputOptions
---@field required ItemStock?
---@field max ItemStock?
---@class TurtleDoHomeworkOutputOptions
---@field kept ItemStock?
---@field ignoreIfFull string[]?
---@param options TurtleDoHomeworkOptions
function TurtleApi.doHomework(options)
    local required = options.input and options.input.required or {}
    local maxPulled = options.input and options.input.max or {}
    local keptOutput = options.output and options.output.kept or {}
    local ignoreIfFull = options.output and options.output.ignoreIfFull or {}

    if not TurtleApi.probe(options.barrel, ItemApi.barrel) then
        error(string.format("expected barrel @ %s", options.barrel))
    end

    if not TurtleApi.probe(options.ioChest, ItemApi.chest) then
        error(string.format("expected chest @ %s", options.ioChest))
    end

    print("[dump] items...")
    TurtleApi.dump(options.barrel)

    if options.drainDropper then
        print("[drain] dropper...")
        TurtleApi.drainStashDropper(options.drainDropper)
    end

    print("[push] output...")
    TurtleApi.pushAllOutput(options.barrel, options.ioChest, keptOutput, ignoreIfFull)
    print("[pull] input...")

    maxPulled[ItemApi.charcoal] = 0
    TurtleApi.pullInput(options.ioChest, options.barrel, nil, maxPulled)

    ---@return ItemStock
    local function getMissingInputStock()
        ---@type ItemStock
        local missing = {}

        for item, quantity in pairs(required) do
            if InventoryPeripheral.getItemCount(options.barrel, item) < quantity then
                missing[item] = quantity - InventoryPeripheral.getItemCount(options.barrel, item)
            end
        end

        return missing
    end

    ---@return boolean
    local function needsMoreInput()
        return not Utils.isEmpty(getMissingInputStock())
    end

    ---@param missing ItemStock
    local function printWaitingForMissingInputStock(missing)
        print("[waiting] for more input to arrive")

        for item, quantity in pairs(missing) do
            print(string.format(" - %dx %s", quantity, item))
        end
    end

    if needsMoreInput() then
        local missing = getMissingInputStock()
        printWaitingForMissingInputStock(missing)

        while needsMoreInput() do
            os.sleep(3)
            TurtleApi.pullInput(options.ioChest, options.barrel, nil, maxPulled)
            local updatedMissing = getMissingInputStock()

            if not ItemStock.isEqual(missing, updatedMissing) then
                missing = updatedMissing
                printWaitingForMissingInputStock(missing)
            end
        end
    end

    print("[input] looks good!")
    print("[fuel] checking for fuel...")
    TurtleApi.refuelTo(options.minFuel, options.barrel, options.ioChest)
    print("[stash] loading up...")
    TurtleApi.suckAll(options.barrel)
end

---@param item string
---@return integer?
function TurtleApi.selectItem(item)
    if TurtleApi.isSimulating() then
        return
    end

    local slot = TurtleApi.find(item) or TurtleApi.loadFromShulker(item)

    if not slot then
        return
    end

    TurtleApi.select(slot)

    return slot
end

---@param predicate fun(stack: ItemStack) : boolean
---@return integer?
function TurtleApi.selectPredicate(predicate)
    for slot = 1, TurtleApi.size() do
        if TurtleApi.getItemCount(slot) > 0 then
            local stack = TurtleApi.getStack(slot, true)

            if stack and predicate(stack) then
                TurtleApi.select(slot)
                return slot
            end
        end
    end
end

---@return boolean
function TurtleApi.tryLoadShulkers()
    if TurtleApi.isSimulating() then
        return true
    end

    local unloadedAll = true

    for slot, stack in pairs(TurtleApi.getStacks()) do
        if stack.name ~= ItemApi.shulkerBox and stack.name ~= ItemApi.diskDrive then
            if not TurtleApi.loadIntoShulker(slot) then
                unloadedAll = false
            end
        end
    end

    TurtleApi.digShulkers()
    return unloadedAll
end

--- Returns the items contained in carried and already placed shulkers.
--- This function is using a cache which might be refreshed during the call:
---
--- - carried shulker boxes are placed and their cache is refreshed only if the nbt tag changed
--- 
--- - the cache of already placed shulker boxes is always refreshed
--- 
--- During this process, carried shulker boxes might be placed and already placed shulker boxes might be removed.
---@return Inventory[]
function TurtleApi.readShulkers()
    return TurtleShulkerApi.readShulkers(TurtleApi)
end

--- Returns how many more shulkers would be needed to carry the given items.
---@param items ItemStock
---@return integer
function TurtleApi.getRequiredAdditionalShulkers(items)
    return TurtleShulkerApi.getRequiredAdditionalShulkers(TurtleApi, items)
end

---@param item string
---@return integer?
function TurtleApi.loadFromShulker(item)
    return TurtleShulkerApi.loadFromShulker(TurtleApi, item)
end

---@param slot integer
---@return boolean success, string? message
function TurtleApi.loadIntoShulker(slot)
    return TurtleShulkerApi.loadIntoShulker(TurtleApi, slot)
end

function TurtleApi.digShulkers()
    TurtleShulkerApi.digShulkers(TurtleApi)
end

---@param items ItemStock
---@param alwaysUseShulkers? boolean
---@return ItemStock, integer
function TurtleApi.getOpenStock(items, alwaysUseShulkers)
    local open = ItemStock.subtract(items, TurtleApi.getStock(true))

    if not alwaysUseShulkers and ItemApi.getRequiredSlotCount(open, defaultItemMaxCount) <= TurtleApi.numEmptySlots() then
        -- the additionally required items fit into the inventory
        return open, 0
    end

    -- the additionally required items don't fit into inventory or the user wants them to be put into shulkers,
    -- so we'll calculate the number of required shulkers based on the items that already exist in inventory
    -- and the items that are still needed.
    local takenInventoryStock = ItemStock.intersect(TurtleApi.getStock(), items)
    local requiredShulkers = TurtleApi.getRequiredAdditionalShulkers(ItemStock.merge({open, takenInventoryStock}))

    if requiredShulkers > maxCarriedShulkers then
        -- [todo] ❌ hacky way of ensuring that the turtle has enough space to carry all the shulkers, as we are
        -- missing logic to figure out how many empty slots we'll have taking into account items in the inventory
        -- which will not be put into shulkers.
        error(string.format("trying to require %d shulkers (max allowed: %d)", requiredShulkers, maxCarriedShulkers))
    end

    return open, requiredShulkers
end

---@param chunkX integer
---@param y integer
---@param chunkZ integer
---@return Vector
function TurtleApi.getChunkCenter(chunkX, y, chunkZ)
    local x = (chunkX * 16) + 8
    local z = (chunkZ * 16) + 8

    return Vector.create(x, y, z)
end

---@return Vector
function TurtleApi.locate()
    local position = TurtleApi.tryGetLivePosition()

    if not position then
        error("no gps available")
    end

    TurtleApi.setPosition(position)

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

    local diskState = DatabaseApi.getTurtleDiskState()
    diskState.diskDriveSides = directions
    DatabaseApi.saveTurtleDiskState(diskState)
    local placedSide = TurtleApi.tryPutAtOneOf(directions, "computercraft:disk_drive")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.diskDriveSides = {}
        diskState.cleanupSides[placedSide] = "computercraft:disk_drive"
        DatabaseApi.saveTurtleDiskState(diskState)
    end

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

    if not TurtleApi.dig(placedSide) then
        error("failed to dig disk drive")
    end

    diskState.diskDriveSides[placedSide] = nil
    DatabaseApi.saveTurtleDiskState(diskState)

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

---@param items ItemStock
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
    local diskState = DatabaseApi.getTurtleDiskState()

    -- [todo] ❓ what is the difference between cleanupSides & diskDriveSides/shulkerSides?
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

        if TurtleApi.probe(side, ItemApi.shulkerBox) then
            TurtleApi.dig(side)
            break
        end
    end

    diskState.cleanupSides = {}
    diskState.diskDriveSides = {}
    diskState.shulkerSides = {}
    DatabaseApi.saveTurtleDiskState(diskState)
end

function TurtleApi.recover()
    local shulkerDirections = {"top", "bottom", "front"}

    for _, direction in pairs(shulkerDirections) do
        if TurtleApi.probe(direction, ItemApi.shulkerBox) then
            TurtleApi.dig(direction)
        end
    end
end

---@param fn fun(inventory: string) : any
function TurtleApi.connectToStorage(fn)
    local wiredModemSide = PeripheralApi.findSide("modem") or error("no wired modem next to me found")

    if not TurtleApi.isWiredModemPowered(wiredModemSide) then
        TurtleApi.use(wiredModemSide, ItemApi.diskDrive, true)
    end

    local storageService = Rpc.nearest(StorageService)
    local inventoryServer = Rpc.server(TurtleInventoryService, wiredModemSide)
    local inventory = inventoryServer.getWiredName()
    local success = true
    local message = nil

    EventLoop.waitForAny(function()
        inventoryServer.open()
    end, function()
        storageService.mount({inventory})

        while true do
            os.sleep(3)
            storageService.refresh({inventory})
        end
    end, function()
        success, message = pcall(function()
            fn(inventory)
        end)
    end)

    inventoryServer.close()

    if not success then
        error(message)
    end
end

return TurtleApi
