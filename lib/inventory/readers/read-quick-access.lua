local constructInventory = require "lib.inventory.construct-inventory"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    ---@type table<integer, InventorySlot>
    local slots = {}

    for slot, _ in pairs(stacks) do
        if slot ~= nameTagSlot then
            slots[slot] = {index = slot, tags = {input = true, withdraw = true}}
        end
    end

    return constructInventory(name, "quick-access", stacks, slots)
end
