local readCommon = require "lib.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot? integer
---@param label? string
---@return Inventory
return function(name, stacks, nameTagSlot, label)
    return readCommon(name, "turtle-buffer", stacks, nameTagSlot, {buffer = true}, label, true)
end
