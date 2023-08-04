local stacksToStock = require "inventory.stacks-to-stock"

---@class Inventory
---@field name string
---@field stock table<string, ItemStack>
---@field stacks table<integer, ItemStack>

local Inventory = {}

---@param name string
---@param stacks ItemStacks
---@return Inventory
function Inventory.create(name, stacks)
    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stacksToStock(stacks)}

    return inventory
end

return Inventory
