local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local constructInventory = require "lib.inventory.construct-inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot? integer
---@param label? string
---@return Inventory
return function(name, stacks, nameTagSlot, label)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.buffer = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return constructInventory(name, "turtle-buffer", stacks, slots, true, label)
end
