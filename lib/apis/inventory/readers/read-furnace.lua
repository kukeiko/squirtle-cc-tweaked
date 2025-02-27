local Inventory = require "lib.models.inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
return function(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}

    slots[1] = {index = 1, tags = {input = true}}
    slots[2] = {index = 2, tags = {fuel = true}}
    slots[3] = {index = 3, tags = {output = true, withdraw = true}}

    ---@type ItemStock
    local items = {}

    for _, stack in pairs(stacks) do
        items[stack.name] = (items[stack.name] or 0) + stack.count
    end

    return Inventory.create(name, "furnace", {stacks[1], stacks[2], stacks[3]}, slots, true, nil, items)
end
