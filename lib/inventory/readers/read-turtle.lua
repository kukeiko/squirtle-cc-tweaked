local Inventory = require "lib.inventory.inventory"
local ItemStock = require "lib.inventory.item-stock"

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
return function(name, stacks)
    ---@type table<integer, InventorySlot>
    local slots = {}
    ---@type InventorySlotTags
    local ioSlotTags = {input = true, output = true}
    ---@type ItemStack[]
    local ioStacks = {}

    for slot = 1, 16 do
        if slot < 13 then
            slots[slot] = {index = slot, tags = {}}
        else
            slots[slot] = {index = slot, tags = ioSlotTags}
            ioStacks[slot] = stacks[slot]
        end
    end

    local items = ItemStock.fromStacks(ioStacks)

    return Inventory.create(name, "turtle", ioStacks, slots, true, nil, items)
end
