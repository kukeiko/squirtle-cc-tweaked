local toIoInventory = require "inventory.to-io-inventory"

---@param chest string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return InputOutputInventory
return function(chest, stacks, nameTagSlot)
    return toIoInventory(chest, stacks, nameTagSlot)
end
