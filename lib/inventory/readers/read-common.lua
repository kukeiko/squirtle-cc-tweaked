local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory"
local Utils = require "lib.common.utils"

---@param name string
---@param type InventoryType
---@param stacks table<integer, ItemStack>
---@param nameTagSlot? integer
---@param slotTags InventorySlotTags
---@param label? string
---@param allowAllocate? boolean
---@return Inventory
return function(name, type, stacks, nameTagSlot, slotTags, label, allowAllocate)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        if slot == nameTagSlot then
            slots[slot] = {index = slot, tags = {nameTag = true}}
        else
            tags = slotTags
            -- [todo] remove clone once cc:tweaked is updated
            slots[slot] = {index = slot, tags = Utils.clone(slotTags)}
        end
    end

    ---@type ItemStock
    local items = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            items[stack.name] = (items[stack.name] or 0) + stack.count
        end
    end

    return Inventory.create(name, type, stacks, slots, allowAllocate, label, items)
end
