local readCommon = require "lib.apis.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return Inventory
return function(name, stacks, nameTagSlot)
    return readCommon(name, "composter-input", stacks, nameTagSlot, {input = true}, nil, true)
end
