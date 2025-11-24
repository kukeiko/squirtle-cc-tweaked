local Utils = require "lib.tools.utils"
local Inventory = require "lib.inventory.inventory"
local ItemStock = require "lib.inventory.item-stock"
local getIoSlots = require "lib.turtle.functions.get-io-slots"

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
    -- [todo] ❌ should be handled by the TurtleInventoryAdapter
    local ioSlots = getIoSlots()

    for slot = 1, 16 do
        if Utils.contains(ioSlots, slot) then
            slots[slot] = {index = slot, tags = ioSlotTags}
            ioStacks[slot] = stacks[slot]
        else
            slots[slot] = {index = slot, tags = {}}
        end
    end

    local items = ItemStock.fromStacks(ioStacks)

    return Inventory.create(name, "turtle", ioStacks, slots, true, nil, items)
end
