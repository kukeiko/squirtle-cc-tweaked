local Utils = require "utils"

---@param stacks table<integer, ItemStack>
---@return table<string, ItemStack>
local function stacksToStock(stacks)
    ---@type table<string, ItemStack>
    local stock = {}

    for _, stack in pairs(stacks) do
        local itemStock = stock[stack.name]

        if not itemStock then
            itemStock = Utils.copy(stack)
            itemStock.count = 0
            itemStock.maxCount = 0
            stock[stack.name] = itemStock
        end

        itemStock.count = itemStock.count + stack.count
        itemStock.maxCount = itemStock.maxCount + stack.maxCount
    end

    return stock
end

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
