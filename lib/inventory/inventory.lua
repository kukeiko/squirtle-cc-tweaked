local Utils = require "utils"
local findSide = require "world.peripheral.find-side"
local getStacks = require "inventory.get-stacks"

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
---@param stacks? ItemStacks
---@param detailed? boolean
---@return Inventory
function Inventory.create(name, stacks, detailed)
    stacks = stacks or Inventory.getStacks(name, detailed)

    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stacksToStock(stacks), locked = false}

    return inventory
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function Inventory.getStacks(name, detailed)
    return getStacks(name, detailed)
end

---@return string?
function Inventory.findChest()
    return findSide("minecraft:chest")
end

---@param chest string
---@return integer
function Inventory.getSize(chest)
    return peripheral.call(chest, "size")
end

---@param name string
function Inventory.countItems(name)
    local stock = stacksToStock(getStacks(name))
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock.count
    end

    return count
end

return Inventory
