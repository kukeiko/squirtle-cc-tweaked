local ItemApi = require "lib.inventory.item-api"

---@class PeripheralInventoryAdapter : InventoryAdapter
local PeripheralInventoryAdapter = {}

---@param inventory string
---@return boolean
function PeripheralInventoryAdapter.isPresent(inventory)
    return peripheral.isPresent(inventory)
end

---@param inventory string
---@return boolean
function PeripheralInventoryAdapter.accept(inventory)
    local types = {peripheral.getType(inventory)}

    return types and types[2] == "inventory"
end

---@param inventory string
---@return integer
function PeripheralInventoryAdapter.getSize(inventory)
    return peripheral.call(inventory, "size")
end

---@param inventory string
---@param slot integer
---@return ItemStack?
function PeripheralInventoryAdapter.getStack(inventory, slot)
    ---@type ItemStack?
    local itemStack = peripheral.call(inventory, "getItemDetail", slot)

    if itemStack and ItemApi.isCustomUnstackable(itemStack.name) then
        itemStack.maxCount = 1
    end

    return itemStack
end

---@param inventory string
---@param detailed? boolean
---@return ItemStacks
function PeripheralInventoryAdapter.getStacks(inventory, detailed)
    ---@type ItemStacks
    local itemStacks = peripheral.call(inventory, "list")

    for _, itemStack in pairs(itemStacks) do
        if itemStack and ItemApi.isCustomUnstackable(itemStack.name) then
            itemStack.maxCount = 1
        end
    end

    return itemStacks
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function PeripheralInventoryAdapter.transfer(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

return PeripheralInventoryAdapter
