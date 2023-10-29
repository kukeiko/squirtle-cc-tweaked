local Inventory = require "inventory.inventory"

---@param chest string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return InputOutputInventory
return function(chest, stacks, nameTagSlot)
    return Inventory.createInputOutput(chest, stacks, nameTagSlot)
end
