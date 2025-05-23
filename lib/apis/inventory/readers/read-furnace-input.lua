local readCommon = require "lib.apis.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    return readCommon(name, "furnace-input", stacks, nameTagSlot, {output = true, withdraw = true}, nil, true)
end
