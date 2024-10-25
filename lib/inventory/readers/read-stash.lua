local readCommon = require "lib.inventory.readers.read-common"

---@param name string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@param label string
---@return Inventory
return function(name, stacks, nameTagSlot, label)
    -- [todo] "buffer" tag is to make io-crafter work. revisit
    return readCommon(name, "stash", stacks, nameTagSlot, {input = true, buffer = true}, label)
end
