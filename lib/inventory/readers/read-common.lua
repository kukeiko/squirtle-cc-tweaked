local ItemStock = require "lib.common.models.item-stock"
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
    local size = InventoryPeripheral.getSize(name)

    for slot = 1, size do
        if slot == nameTagSlot then
            slots[slot] = {index = slot, tags = {nameTag = true}}
        else
            tags = slotTags
            -- [todo] remove clone once cc:tweaked is updated
            slots[slot] = {index = slot, tags = Utils.clone(slotTags)}
        end
    end

    local items = ItemStock.fromStacks(stacks, {nameTagSlot})

    return Inventory.create(name, type, stacks, slots, allowAllocate, label, items)
end
