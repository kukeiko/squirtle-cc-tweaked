local readCommon = require "lib.apis.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@return Inventory
return function(name, stacks)
    print("[dbg] reading turtle")
    return readCommon(name, "turtle", stacks, nil, {input = true, output = true}, nil, true)
end
