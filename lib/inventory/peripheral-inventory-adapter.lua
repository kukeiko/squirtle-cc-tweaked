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
    return peripheral.call(inventory, "getItemDetail", slot)
end

---@param inventory string
---@param detailed? boolean
---@return ItemStacks
function PeripheralInventoryAdapter.getStacks(inventory, detailed)
    return peripheral.call(inventory, "list")
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
