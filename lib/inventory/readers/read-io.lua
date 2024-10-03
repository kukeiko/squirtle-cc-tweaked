local constructInventory = require "lib.inventory.construct-inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1

            if slot < nameTagSlot then
                slots[slot] = {index = slot, permanent = true, tags = {input = true}}
            elseif slot > nameTagSlot then
                slots[slot] = {index = slot, permanent = true, tags = {output = true, withdraw = true}}
            end
        else
            slots[slot] = {index = slot, tags = {nameTag = true}}
        end
    end

    return constructInventory(name, "io", stacks, slots)
end
