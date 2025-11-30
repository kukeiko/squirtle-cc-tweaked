local ItemStock = require "lib.inventory.item-stock"
local ItemApi = require "lib.inventory.item-api"
local PeripheralInventoryAdapter = require "lib.inventory.peripheral-inventory-adapter"

---@class InventoryPeripheral
---@field adapters InventoryAdapter[]
local InventoryPeripheral = {adapters = {PeripheralInventoryAdapter}}

---@class InventoryAdapter
---@field isPresent fun(inventory: string): boolean
---@field accept fun(inventory: string): boolean
---@field getSize fun(inventory: string): integer
---@field getStack fun(inventory: string, slot: integer): ItemStack?
---@field getStacks fun(inventory: string, detailed?: boolean): ItemStacks
---@field transfer fun(from: string, to: string, fromSlot: integer, limit?: integer, toSlot?: integer): integer
---

---@param item string
---@param chest string
---@param slot integer
local function readItemMaxCount(item, chest, slot)
    if not ItemApi.hasItemDetail(item) then
        ---@type ItemStack|nil
        local detailedStack = InventoryPeripheral.getStack(chest, slot)

        if detailedStack then
            ItemApi.addItemDetail({name = item, displayName = detailedStack.displayName, maxCount = detailedStack.maxCount})
        end
    end

    return ItemApi.getItemMaxCount(item)
end

---@param inventory string
---@return InventoryAdapter?
local function tryGetAdapter(inventory)
    for _, adapter in pairs(InventoryPeripheral.adapters) do
        if adapter.accept(inventory) then
            return adapter
        end
    end
end

---@param inventory string
---@return InventoryAdapter
local function getAdapter(inventory)
    return tryGetAdapter(inventory) or error(string.format("no inventory adapter for %s", inventory))
end

---@param adapter InventoryAdapter
function InventoryPeripheral.addAdapter(adapter)
    table.insert(InventoryPeripheral.adapters, adapter)
end

---@param inventory string
---@return boolean
function InventoryPeripheral.isPresent(inventory)
    local adapter = tryGetAdapter(inventory)

    if not adapter then
        return false
    end

    return adapter.isPresent(inventory)
end

---@param inventory string
---@return integer?
function InventoryPeripheral.getFirstOccupiedSlot(inventory)
    local stacks = InventoryPeripheral.getStacks(inventory)

    for slot = 1, InventoryPeripheral.getSize(inventory) do
        if stacks[slot] then
            return slot
        end
    end
end

---@param inventory string
---@return integer
function InventoryPeripheral.getSize(inventory)
    return getAdapter(inventory).getSize(inventory)
end

---@param inventory string
---@param slot integer
---@return ItemStack?
function InventoryPeripheral.getStack(inventory, slot)
    local detailedStack = getAdapter(inventory).getStack(inventory, slot)

    if detailedStack then
        ItemApi.addItemDetail({name = detailedStack.name, displayName = detailedStack.displayName, maxCount = detailedStack.maxCount})
    end

    return detailedStack
end

---@param inventory string
---@param detailed? boolean
---@return ItemStacks
function InventoryPeripheral.getStacks(inventory, detailed)
    local adapter = getAdapter(inventory)

    if not detailed then
        ---@type ItemStacks
        local stacks = adapter.getStacks(inventory)

        for slot, stack in pairs(stacks) do
            stack.maxCount = readItemMaxCount(stack.name, inventory, slot)
        end

        return stacks
    else
        local stacks = adapter.getStacks(inventory, detailed)
        ---@type ItemStacks
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = InventoryPeripheral.getStack(inventory, slot)
        end

        return detailedStacks
    end
end

---@param inventory string
---@return ItemStock
function InventoryPeripheral.getStock(inventory)
    local stacks = InventoryPeripheral.getStacks(inventory)
    return ItemStock.fromStacks(stacks)
end

---@param inventory string
---@return integer
function InventoryPeripheral.numEmptySlots(inventory)
    local size = InventoryPeripheral.getSize(inventory)

    for _ in pairs(InventoryPeripheral.getStacks(inventory)) do
        size = size - 1
    end

    return size
end

---@param inventory string
---@param item string
---@return integer
function InventoryPeripheral.getItemCount(inventory, item)
    local count = 0

    for _, stack in pairs(InventoryPeripheral.getStacks(inventory)) do
        if stack.name == item then
            count = count + stack.count
        end
    end

    return count
end

---@param inventory string
---@param item string
---@return integer?
function InventoryPeripheral.findItem(inventory, item)
    for slot, stack in pairs(InventoryPeripheral.getStacks(inventory)) do
        if stack.name == item then
            return slot
        end
    end
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function InventoryPeripheral.transfer(from, to, fromSlot, limit, toSlot)
    local adapter = getAdapter(from)
    os.sleep(.25) -- [note] intentional nerf to the whole inventory system
    return adapter.transfer(from, to, fromSlot, limit, toSlot)
end

---@param inventory string
---@param fromSlot integer
---@param toSlot? integer
---@param quantity? integer
---@return integer
function InventoryPeripheral.move(inventory, fromSlot, toSlot, quantity)
    return InventoryPeripheral.transfer(inventory, inventory, fromSlot, quantity, toSlot)
end

return InventoryPeripheral
