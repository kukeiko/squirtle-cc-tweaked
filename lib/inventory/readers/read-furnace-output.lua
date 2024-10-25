local readCommon = require "lib.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    return readCommon(name, "furnace-output", stacks, nameTagSlot, {input = true, output = true, withdraw = true}, nil, true)
end
