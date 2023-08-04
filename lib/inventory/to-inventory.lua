local getStacks = require "inventory.get-stacks"
local Inventory = require "inventory.inventory"

---@param name string
---@return Inventory
return function(name)
    return Inventory.create(name, getStacks(name))
end
