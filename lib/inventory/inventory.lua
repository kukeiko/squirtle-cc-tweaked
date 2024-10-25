local Inventory = {}

---@param name string
---@param type InventoryType
---@param stacks ItemStacks
---@param slots table<integer, InventorySlot>
---@param allowAllocate? boolean
---@param label? string
---@param items? table<string, integer>
---@return Inventory
function Inventory.create(name, type, stacks, slots, allowAllocate, label, items)
    ---@type Inventory
    local inventory = {
        name = name,
        type = type,
        stacks = stacks,
        allowAllocate = allowAllocate or false,
        slots = slots,
        label = label,
        items = items
    }

    return inventory
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param item string
---@return boolean
function Inventory.slotCanProvideItem(slot, stack, tag, item)
    return stack ~= nil and slot.tags[tag] and stack.count > 0 and stack.name == item
end

---@param slot InventorySlot
---@param stack? ItemStack
---@param tag InventorySlotTag
---@param allowAllocate boolean
---@param item string
---@return boolean
function Inventory.slotCanTakeItem(slot, stack, tag, allowAllocate, item)
    return slot.tags[tag] and ((stack and stack.name == item and stack.count < stack.maxCount) or (not stack and allowAllocate))
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canProvideItem(inventory, item, tag)
    if inventory.items and not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return true
        end
    end

    return false
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return boolean
function Inventory.canTakeItem(inventory, item, tag)
    if not inventory.allowAllocate and inventory.items and not inventory.items[item] then
        return false
    end

    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            return true
        end
    end

    return false
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot, ItemStack? stack
function Inventory.nextFromStack(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        local stack = inventory.stacks[index]

        if Inventory.slotCanProvideItem(slot, stack, tag, item) then
            return slot, stack
        end
    end
end

---@param inventory Inventory
---@param item string
---@param tag InventorySlotTag
---@return InventorySlot? slot
function Inventory.nextToSlot(inventory, item, tag)
    for index, slot in pairs(inventory.slots) do
        if Inventory.slotCanTakeItem(slot, inventory.stacks[index], tag, inventory.allowAllocate, item) then
            return slot
        end
    end
end

return Inventory
