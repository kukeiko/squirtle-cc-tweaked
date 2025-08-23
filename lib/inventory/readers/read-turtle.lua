local readCommon = require "lib.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
return function(name, stacks)
    return readCommon(name, "turtle", stacks, nil, {input = true, output = true}, nil, true)
end
