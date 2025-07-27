local Utils = require "lib.tools.utils"
local Inventory = require "lib.models.inventory"
local ItemStock = require "lib.models.item-stock"
local ItemApi = require "lib.apis.item-api"
local DatabaseApi = require "lib.apis.database.database-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"

---@class TurtleShulkerApi
local TurtleShulkerApi = {}

---@param size integer
---@return table<integer, InventorySlot>
local function getShulkerSlots(size)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local slotTags = {}

    for slot = 1, size do
        tags = slotTags
        slots[slot] = {index = slot, tags = slotTags}
    end

    -- [todo] ❌ for testing only
    -- return slots
    return {}
end

---@param side string
---@param name? string
---@return Inventory
local function readPlacedShulker(side, name)
    local size = InventoryPeripheral.getSize(side)
    local stacks = InventoryPeripheral.getStacks(side)
    local slots = getShulkerSlots(size)
    local items = ItemStock.fromStacks(stacks)

    return Inventory.create(name or "", "shulker", stacks, slots, true, nil, items)
end

local function createEmptyCarriedShulker()
    return Inventory.create("", "shulker", {}, getShulkerSlots(27), true)
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
        print("[dbg] insert new")
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
---@return PlaceSide
local function placeShulker(TurtleApi, slot)
    local item = TurtleApi.getStack(slot)

    if not item then
        error(string.format("no item in slot %d", slot or TurtleApi.getSelectedSlot()))
    end

    local diskState = DatabaseApi.getTurtleDiskState()
    diskState.shulkerSides = TurtleApi.getShulkerSides()
    DatabaseApi.saveTurtleDiskState(diskState)

    TurtleApi.select(slot)
    local placedSide = TurtleApi.placeAtOneOf(TurtleApi.getShulkerSides()) or replaceShulkerAtOneOf(TurtleApi, TurtleApi.getShulkerSides())

    if not placedSide then
        error("failed to place shulker")
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
---@param name string
---@return boolean
local function isCached(TurtleApi, name)
    return Utils.find(TurtleApi.getState().shulkers, function(candidate)
        return candidate.name == name
    end) ~= nil
end

---@param TurtleApi TurtleApi
---@return boolean
local function indexUncachedShulker(TurtleApi)
    -- we need to read already placed shulkers first as they might get removed to read the contents of carried shulkers
    for _, side in pairs(TurtleApi.getState().shulkerSides) do
        if peripheral.getType(side) == ItemApi.shulkerBox and not isCached(TurtleApi, side) then
            print("[digShulker] foo")
            local shulker = readPlacedShulker(side, side)
            print("[digShulker] bar")
            table.insert(TurtleApi.getState().shulkers, shulker)

            return true
        end
    end

    for slot, item in pairs(TurtleApi.getStacks()) do
        if item.name == ItemApi.shulkerBox then
            if item.nbt and not isCached(TurtleApi, item.nbt) then
                print(item.nbt)
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
local function getValidatedRefreshedCache(TurtleApi)
    ---@type string[]
    local expectedShulkerNames = {}

    for _, side in pairs(TurtleApi.getShulkerSides()) do
        if peripheral.getType(side) == ItemApi.shulkerBox then
            table.insert(expectedShulkerNames, side)
        end
    end

    for _, item in pairs(TurtleApi.getStacks()) do
        if item.name == ItemApi.shulkerBox then
            table.insert(expectedShulkerNames, item.nbt or "")
        end
    end

    ---@type Inventory[]
    local shulkers = {}
    local cache = Utils.reverse(TurtleApi.getState().shulkers)

    for _, name in pairs(expectedShulkerNames) do
        local shulker, index = Utils.find(cache, function(candidate)
            return candidate.name == name
        end)

        if not shulker then
            error(string.format("did not find shulker %s in cache", name))
        end

        table.insert(shulkers, Utils.clone(shulker))

        if name == "" or Utils.contains(TurtleApi.getState().shulkerSides, name) then
            table.remove(cache, index)
        end
    end

    return shulkers
end

---@param TurtleApi TurtleApi
---@return Inventory[]
function TurtleShulkerApi.readShulkers(TurtleApi)
    while indexUncachedShulker(TurtleApi) do
    end

    local shulkers = getValidatedRefreshedCache(TurtleApi)
    TurtleApi.getState().shulkers = shulkers

    return shulkers
end

---@param TurtleApi TurtleApi
---@param nbt? string
---@return PlaceSide
function TurtleShulkerApi.mountShulker(TurtleApi, nbt)
    error("not implemented")
end

---@param side PlaceSide
function TurtleShulkerApi.unmountShulker(side)
    error("not implemented")
end

---@param item string
---@return integer
function TurtleShulkerApi.loadFromShulker(item)
    error("not implemented")
end

return TurtleShulkerApi
