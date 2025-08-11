local Utils = require "lib.tools.utils"
local Inventory = require "lib.models.inventory"
local ItemStock = require "lib.models.item-stock"
local ItemApi = require "lib.apis.item-api"
local DatabaseApi = require "lib.apis.database.database-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"

---@class TurtleShulkerApi
local TurtleShulkerApi = {}
local shulkerSlotCount = 27
local defaultItemMaxCount = 64

---@param size integer
---@return table<integer, InventorySlot>
local function createShulkerSlots(size)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local slotTags = {buffer = true}

    for slot = 1, size do
        tags = slotTags
        slots[slot] = {index = slot, tags = slotTags}
    end

    return slots
end

---@param side string
---@param name? string
---@return Inventory
local function readPlacedShulker(side, name)
    local stacks = InventoryPeripheral.getStacks(side)
    local slots = createShulkerSlots(shulkerSlotCount)
    local items = ItemStock.fromStacks(stacks)

    return Inventory.create(name or "", "shulker", stacks, slots, true, nil, items)
end

local function createEmptyCarriedShulker()
    return Inventory.create("", "shulker", {}, createShulkerSlots(shulkerSlotCount), true)
end

---@param TurtleApi TurtleApi
---@param old string
---@param new string
---@return boolean
local function replaceCachedShulkerName(TurtleApi, old, new)
    for _, shulker in pairs(TurtleApi.getState().shulkers) do
        if shulker.name == old then
            shulker.name = new
            return true
        end
    end

    return false
end

---@param TurtleApi TurtleApi
---@param name string
---@param shulker Inventory
---@return boolean
local function replaceCachedShulker(TurtleApi, name, shulker)
    for i, candidate in pairs(TurtleApi.getState().shulkers) do
        if candidate.name == name then
            TurtleApi.getState().shulkers[i] = shulker
            return true
        end
    end

    return false
end

---@param TurtleApi TurtleApi
---@param side PlaceSide
local function digShulker(TurtleApi, side)
    if not peripheral.getType(side) == ItemApi.shulkerBox then
        error(string.format("no shulker box present at %s", side))
    end

    local shulker = readPlacedShulker(side)
    TurtleApi.selectEmpty()

    if not TurtleApi.dig(side) then
        error(string.format("failed to dig shulker at %s", side))
    end

    while peripheral.isPresent(side) do
        os.sleep(.1)
    end

    local item = TurtleApi.getStack()

    if not item then
        error(string.format("no item in slot %d", TurtleApi.getSelectedSlot()))
    end

    shulker.name = item.nbt or ""

    if not replaceCachedShulker(TurtleApi, item.nbt or "", shulker) then
        table.insert(TurtleApi.getState().shulkers, shulker)
    end

    -- [todo] ❌ possible issue as this function is called during placeShulker() which also updates DiskState
    local diskState = DatabaseApi.getTurtleDiskState()
    diskState.shulkerSides = {}
    diskState.cleanupSides[side] = nil
    DatabaseApi.saveTurtleDiskState(diskState)
end

---@param TurtleApi TurtleApi
---@param sides PlaceSide[]
---@return PlaceSide?
local function replaceShulkerAtOneOf(TurtleApi, sides)
    local slot = TurtleApi.getSelectedSlot()

    for _, side in pairs(sides) do
        if peripheral.getType(side) == ItemApi.shulkerBox then
            digShulker(TurtleApi, side)
            TurtleApi.select(slot)

            if not TurtleApi.place(side) then
                error(string.format("failed to place shulker at %s", side))
            end

            return side
        end
    end
end

---@param TurtleApi TurtleApi
---@param slot integer
---@return PlaceSide?, string?
local function tryPlaceShulker(TurtleApi, slot)
    local item = TurtleApi.getStack(slot)

    if not item then
        error(string.format("no item in slot %d", slot or TurtleApi.getSelectedSlot()))
    elseif item.name ~= ItemApi.shulkerBox then
        error(string.format("item in slot %d is not a shulker", slot))
    end

    local diskState = DatabaseApi.getTurtleDiskState()
    diskState.shulkerSides = TurtleApi.getShulkerSides()
    DatabaseApi.saveTurtleDiskState(diskState)

    TurtleApi.select(slot)
    local placedSide = TurtleApi.placeAtOneOf(TurtleApi.getShulkerSides()) or replaceShulkerAtOneOf(TurtleApi, TurtleApi.getShulkerSides())

    if not placedSide then
        diskState.shulkerSides = {}
        DatabaseApi.saveTurtleDiskState(diskState)

        return nil, "failed to place shulker"
    end

    replaceCachedShulkerName(TurtleApi, item.nbt or "", placedSide)

    diskState.shulkerSides = {}
    diskState.cleanupSides[placedSide] = ItemApi.shulkerBox
    DatabaseApi.saveTurtleDiskState(diskState)

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    return placedSide
end

---@param TurtleApi TurtleApi
---@param slot integer
---@return PlaceSide
local function placeShulker(TurtleApi, slot)
    local placedSide, message = tryPlaceShulker(TurtleApi, slot)

    if not placedSide then
        error(message)
    end

    return placedSide
end

---@param TurtleApi TurtleApi
---@param name string
---@return PlaceSide?, string?
local function placeShulkerByName(TurtleApi, name)
    if Utils.contains(TurtleApi.getShulkerSides(), name) then
        return name
    end

    for slot, item in pairs(TurtleApi.getStacks()) do
        if item.name == ItemApi.shulkerBox and (item.nbt or "") == name then
            return placeShulker(TurtleApi, slot)
        end
    end

    error(string.format("no shulker found w/ name %s", name))
end

---@param TurtleApi TurtleApi
---@param item string
---@return PlaceSide?, string?
local function placeShulkerTakingItem(TurtleApi, item)
    local shulkers = TurtleShulkerApi.readShulkers(TurtleApi)

    for _, shulker in pairs(shulkers) do
        if shulker.items[item.name] and Inventory.canTakeItem(shulker, item, "buffer") then
            return placeShulkerByName(TurtleApi, shulker.name)
        end
    end

    for _, shulker in pairs(shulkers) do
        if Inventory.canTakeItem(shulker, item, "buffer") then
            return placeShulkerByName(TurtleApi, shulker.name)
        end
    end

    error(string.format("no shulker available to take item %s", item))
end

---@param TurtleApi TurtleApi
---@param name string
---@return boolean
local function isCached(TurtleApi, name)
    local shulker = Utils.find(Utils.reverse(TurtleApi.getState().shulkers), function(candidate)
        return candidate.name == name
    end)

    if shulker == nil then
        return false
    elseif Utils.contains(TurtleApi.getShulkerSides(), name) then
        return ItemStock.isEqual(shulker.items, InventoryPeripheral.getStock(name))
    else
        return true
    end
end

---@param TurtleApi TurtleApi
---@return boolean
local function indexUncachedShulker(TurtleApi)
    -- we need to read already placed shulkers first as they might get removed to read the contents of carried shulkers
    for _, side in pairs(TurtleApi.getState().shulkerSides) do
        if peripheral.getType(side) == ItemApi.shulkerBox and not isCached(TurtleApi, side) then
            local shulker = readPlacedShulker(side, side)
            table.insert(TurtleApi.getState().shulkers, shulker)

            return true
        end
    end

    for slot, item in pairs(TurtleApi.getStacks()) do
        if item.name == ItemApi.shulkerBox then
            if item.nbt and not isCached(TurtleApi, item.nbt) then
                digShulker(TurtleApi, placeShulker(TurtleApi, slot))

                return true
            elseif not item.nbt then
                local shulker = createEmptyCarriedShulker()
                table.insert(TurtleApi.getState().shulkers, shulker)
            end
        end
    end

    return false
end

---@param TurtleApi TurtleApi
---@return string[]
local function getPresentShulkerNames(TurtleApi)
    ---@type string[]
    local names = {}

    -- placed shulkers need to be first so that item lookups prefer those
    for _, side in pairs(TurtleApi.getShulkerSides()) do
        if peripheral.getType(side) == ItemApi.shulkerBox then
            table.insert(names, side)
        end
    end

    for _, item in pairs(TurtleApi.getStacks()) do
        if item.name == ItemApi.shulkerBox then
            table.insert(names, item.nbt or "")
        end
    end

    return names
end

---@param TurtleApi TurtleApi
---@return Inventory[]
function TurtleShulkerApi.readShulkers(TurtleApi)
    -- read every present shulker into the cache. I've chosen to do it in a while loop like this
    -- so that this works even if a player manipulates the inventory of the turtle.
    while indexUncachedShulker(TurtleApi) do
    end

    -- after, we make sure the cache is not stale by only keeping present shulkers
    ---@type Inventory[]
    local shulkers = {}
    local cache = Utils.reverse(TurtleApi.getState().shulkers) -- we want oldest last

    for _, name in pairs(getPresentShulkerNames(TurtleApi)) do
        local shulker = Utils.find(cache, function(candidate)
            return candidate.name == name
        end)

        if not shulker then
            error(string.format("did not find shulker %s in cache", name))
        end

        -- cloning is required as we might carry 2x equal shulkers which would be only 1x entry in cache
        table.insert(shulkers, Utils.clone(shulker))
    end

    TurtleApi.getState().shulkers = shulkers

    return Utils.clone(shulkers)
end

---@param TurtleApi TurtleApi
function TurtleShulkerApi.getShulkerStock(TurtleApi)
    local shulkers = TurtleShulkerApi.readShulkers(TurtleApi)

    return ItemStock.merge(Utils.map(shulkers, function(shulker)
        return shulker.items
    end))
end

---@param TurtleApi TurtleApi
---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(TurtleApi, alsoIgnoreSlot)
    for slot = 1, TurtleApi.size() do
        if alsoIgnoreSlot ~= slot then
            local item = TurtleApi.getStack(slot)

            if item and item.name ~= ItemApi.shulkerBox then
                return slot
            end
        end
    end
end

---@param TurtleApi TurtleApi
---@param item string
---@return integer?
function TurtleShulkerApi.loadFromShulker(TurtleApi, item)
    local shulkers = TurtleShulkerApi.readShulkers(TurtleApi)
    local shulker = Utils.find(shulkers, function(candidate)
        return candidate.items[item] ~= nil
    end)

    if not shulker then
        return
    end

    ---@type PlaceSide
    local side

    if Utils.contains(TurtleApi.getState().shulkerSides, shulker.name) then
        side = shulker.name
    else
        local slot = TurtleApi.find(ItemApi.shulkerBox, shulker.name)

        if not slot then
            error(string.format("shulker containing %s unexpectedly missing", item))
        end

        side = placeShulker(TurtleApi, slot)
    end

    local slot = TurtleApi.selectEmpty()

    for stackSlot, stack in pairs(shulker.stacks) do
        if stack.name == item then
            -- [todo] ❌ ideally, we suck it into a slot that already contains that item
            TurtleApi.suckSlot(side, stackSlot)
            local emptySlot = TurtleApi.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(TurtleApi, slot)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                TurtleApi.select(slotToPutIntoShulker)
                TurtleApi.drop(side)
                TurtleApi.select(slot)
            end

            digShulker(TurtleApi, side)

            return slot
        end
    end

    digShulker(TurtleApi, side)
end

---@param TurtleApi TurtleApi
---@param slot integer
---@return boolean success, string? message
function TurtleShulkerApi.loadIntoShulker(TurtleApi, slot)
    local item = TurtleApi.getStack(slot)

    if not item then
        error(string.format("no item in slot %d"))
    end

    local open = item.count

    while open > 0 do
        local placedSide, message = placeShulkerTakingItem(TurtleApi, item.name)

        if not placedSide then
            return false, message
        end

        TurtleApi.select(slot)
        -- [todo] ❌ need a more intelligent drop, should drop into slots that already contain the item
        TurtleApi.drop(placedSide)
        item = TurtleApi.getStack(slot)
        open = item and item.count or 0
    end

    return true
end

---@param TurtleApi TurtleApi
function TurtleShulkerApi.digShulkers(TurtleApi)
    for _, side in pairs(TurtleApi.getShulkerSides()) do
        if peripheral.getType(side) == ItemApi.shulkerBox then
            digShulker(TurtleApi, side)
        end
    end
end

---@param item string
---@param quantity integer
---@param shulker Inventory
---@return integer
local function fakeMoveItem(item, quantity, shulker)
    local nextSlot, nextStack = Inventory.nextToStack(shulker, item, "buffer")

    if not nextSlot then
        return 0
    elseif not nextStack then
        nextStack = {count = 0, name = item, maxCount = ItemApi.getItemMaxCount(item, defaultItemMaxCount)}
        shulker.stacks[nextSlot.index] = nextStack
    end

    -- [todo] ❌ similar/duplicate logic as in moveItem()
    local moved = math.min(nextStack.maxCount - nextStack.count, quantity)
    nextStack.count = nextStack.count + moved

    if not shulker.items[item] then
        shulker.items[item] = 0
    end

    shulker.items[item] = shulker.items[item] + moved

    return moved
end

---@param item string
---@param quantity integer
---@param shulker Inventory
---@return integer
local function fakeMoveItemFully(item, quantity, shulker)
    local open = quantity

    while open > 0 do
        local moved = fakeMoveItem(item, open, shulker)

        if moved == 0 then
            break
        end

        open = open - moved
    end

    return quantity - open
end

---@param TurtleApi TurtleApi
---@param items ItemStock
---@return integer
function TurtleShulkerApi.getRequiredAdditionalShulkers(TurtleApi, items)
    local shulkers = TurtleShulkerApi.readShulkers(TurtleApi)
    local open = Utils.copy(items)

    for _, shulker in pairs(shulkers) do
        for item in pairs(shulker.items) do
            if open[item] then
                open[item] = open[item] - fakeMoveItemFully(item, open[item], shulker)

                if open[item] == 0 then
                    open[item] = nil
                end
            end
        end
    end

    for _, item in pairs(Utils.getKeys(open)) do
        for _, shulker in pairs(shulkers) do
            open[item] = open[item] - fakeMoveItemFully(item, open[item], shulker)

            if open[item] == 0 then
                open[item] = nil
                break
            end
        end
    end

    if Utils.isEmpty(open) then
        return 0
    end

    return math.ceil(ItemApi.getRequiredSlotCount(open, defaultItemMaxCount) / shulkerSlotCount)
end

return TurtleShulkerApi
