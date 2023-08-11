local stacksToStock = require "inventory.stacks-to-stock"

---@class Inventory
---@field name string
---@field stock ItemStock
---@field stacks ItemStacks
---@field locked boolean

local Inventory = {}

---@param name string
---@param stacks ItemStacks
---@return Inventory
function Inventory.create(name, stacks)
    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stacksToStock(stacks), locked = false}

    return inventory
end

return Inventory
