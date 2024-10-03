---@param name string
---@param type InventoryType
---@param stacks ItemStacks
---@param slots table<integer, InventorySlot>
---@param allowAllocate? boolean
---@param label? string
---@param items? table<string, true>
---@return Inventory
return function(name, type, stacks, slots, allowAllocate, label, items)
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
