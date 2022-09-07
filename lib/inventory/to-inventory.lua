local getStacks = require "inventory.get-stacks"
local stacksToStock = require "inventory.stacks-to-stock"

---@param name string
---@return Inventory
return function(name)
    local stacks = getStacks(name)

    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stacksToStock(stacks)}

    return inventory
end
