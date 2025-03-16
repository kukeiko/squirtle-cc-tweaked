local ItemStock = require "lib.models.item-stock"

---@class InventoryPeripheral
local InventoryPeripheral = {}

---@type ItemDetails
local itemDetails = {}

---@param item string
---@param chest string
---@param slot integer
local function readItemMaxCount(item, chest, slot)
    if not itemDetails[item] then
        ---@type ItemStack|nil
        local detailedStack = InventoryPeripheral.getStack(chest, slot)

        if detailedStack then
            itemDetails[item] = {name = item, displayName = detailedStack.displayName, maxCount = detailedStack.maxCount}
        end
    end

    return itemDetails[item].maxCount
end

---@param item string
---@return integer
function InventoryPeripheral.getItemMaxCount(item)
    if not itemDetails[item] then
        error(string.format("no max count available for item %s", item))
    end

    return itemDetails[item].maxCount
end

---@return ItemDetails
function InventoryPeripheral.getItemDetails()
    return itemDetails
end

---@param stock ItemStock
---@return integer
function InventoryPeripheral.getRequiredSlotCount(stock)
    local slotCount = 0

    for item, quantity in pairs(stock) do
        slotCount = slotCount + math.ceil(quantity / InventoryPeripheral.getItemMaxCount(item))
    end

    return slotCount
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
    return peripheral.call(inventory, "size")
end

---@param side string
---@param slot integer
---@return ItemStack
function InventoryPeripheral.getStack(side, slot)
    return peripheral.call(side, "getItemDetail", slot)
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function InventoryPeripheral.getStacks(name, detailed)
    if not detailed then
        ---@type ItemStacks
        local stacks = peripheral.call(name, "list")

        for slot, stack in pairs(stacks) do
            stack.maxCount = readItemMaxCount(stack.name, name, slot)
        end

        return stacks
    else
        local stacks = peripheral.call(name, "list")
        ---@type ItemStacks
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = InventoryPeripheral.getStack(name, slot)
        end

        return detailedStacks
    end
end

---@param name string
---@return ItemStock
function InventoryPeripheral.getStock(name)
    local stacks = InventoryPeripheral.getStacks(name)
    return ItemStock.fromStacks(stacks)
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
function InventoryPeripheral.pushItems(from, to, fromSlot, limit, toSlot)
    os.sleep(.25)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param inventory string
---@param fromSlot integer
---@param toSlot? integer
---@param quantity? integer
---@return integer
function InventoryPeripheral.move(inventory, fromSlot, toSlot, quantity)
    os.sleep(.25) -- [note] exists on purpose, as I don't want turtles to move items too quickly in suckSlot()
    return InventoryPeripheral.pushItems(inventory, inventory, fromSlot, quantity, toSlot)
end

return InventoryPeripheral
