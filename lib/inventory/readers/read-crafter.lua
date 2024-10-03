local Utils = require "lib.common.utils"
local constructInventory = require "lib.inventory.construct-inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    local inputSlotOffset = 3
    local outputSlotOffset = 6

    ---@param slots table<integer, InventorySlot>
    ---@param offset integer
    ---@param tags InventorySlotTags
    local function fillSlots(slots, offset, tags)
        for i = 1, 9 do
            local line = math.ceil(i / 3)
            local offsetRight = (line - 1) * (9 - (offset + 3))
            local slot = i + (offset * line) + offsetRight

            slots[slot] = {index = slot, tags = Utils.clone(tags)}
        end
    end

    -- [todo] nameTag slot handling missing - mainly because current crafter code
    -- changes position of it, and I have not yet decided how I wanna deal with that.
    ---@type table<integer, InventorySlot>
    local slots = {}
    fillSlots(slots, inputSlotOffset, {input = true})
    fillSlots(slots, outputSlotOffset, {output = true})

    return constructInventory(name, "crafter", stacks, slots, true)
end
