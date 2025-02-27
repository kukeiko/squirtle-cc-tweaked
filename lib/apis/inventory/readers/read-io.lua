local Utils = require "lib.tools.utils"
local Inventory = require "lib.models.inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local inputTags = {input = true}
    ---@type InventorySlotTags
    local outputTags = {output = true, withdraw = true}
    ---@type ItemStock
    local items = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1
            items[stack.name] = (items[stack.name] or 0) + stack.count

            if slot < nameTagSlot then
                -- [todo] remove clone once cc:tweaked is updated
                slots[slot] = {index = slot, permanent = true, tags = Utils.clone(inputTags)}
            elseif slot > nameTagSlot then
                -- [todo] remove clone once cc:tweaked is updated
                slots[slot] = {index = slot, permanent = true, tags = Utils.clone(outputTags)}
            end
        else
            slots[slot] = {index = slot, tags = {nameTag = true}}
        end
    end

    return Inventory.create(name, "io", stacks, slots, false, nil, items)
end
