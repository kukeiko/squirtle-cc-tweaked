local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local constructInventory = require "lib.inventory.construct-inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot = 1, InventoryPeripheral.getSize(name) do
        ---@type InventorySlotTags
        local tags = {}

        if slot == nameTagSlot then
            tags.nameTag = true
        else
            tags.input = true
            tags.output = true
            tags.withdraw = true
        end

        slots[slot] = {index = slot, tags = tags}
    end

    return constructInventory(name, "furnace-output", stacks, slots, true)
end
