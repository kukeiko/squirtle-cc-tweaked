local Utils = require "utils"
local InventoryBasic = require "inventory.inventory-basic"
local InventoryElemental = require "inventory.inventory-elemental"
local InventoryComplex = require "inventory.inventory-complex"

---@class InventoryApi:InventoryComplex
local Inventory = {}
setmetatable(Inventory, {__index = InventoryComplex})

---@param name string
---@return ItemStock
function Inventory.getStock(name)
    return InventoryElemental.stacksToStock(Inventory.getStacks(name))
end

---@param name string
---@return ItemStock
function Inventory.getInputStock(name)
    return InventoryElemental.stacksToStock(Inventory.getInputStacks(name, true))
end

---@param name string
function Inventory.countItems(name)
    local stock = InventoryElemental.stacksToStock(Inventory.getStacks(name))
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock.count
    end

    return count
end

---@param side string
---@param predicate string|function<boolean, ItemStack>
---@return integer
function Inventory.getItemStock(side, predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Inventory.getStacks(side)) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function Inventory.getInputStacks(name, detailed)
    ---@type ItemStacks
    local inputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = InventoryBasic.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot < nameTagSlot then
                inputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) > 27 then -- 2+ wide - assumed to be a storage chest (=> input)
        inputStacks = stacks
    end

    if detailed then
        for slot in pairs(inputStacks) do
            inputStacks[slot] = InventoryElemental.getStack(name, slot)
        end
    end

    return inputStacks
end

---@param name string
---@param detailed? boolean
function Inventory.getOutputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = InventoryBasic.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) == 27 then -- 1 wide - assumed to be a autofarm chest (=> output)
        outputStacks = stacks
    end

    if detailed then
        for slot in pairs(outputStacks) do
            outputStacks[slot] = InventoryElemental.getStack(name, slot)
        end
    end

    return outputStacks
end

---@param name string
---@return table<string, integer>
function Inventory.getOutputMissingStock(name)
    ---@type table<string, integer>
    local missingStock = {}
    local stock = InventoryElemental.stacksToStock(Inventory.getOutputStacks(name))

    for item, stack in pairs(stock) do
        missingStock[item] = stack.maxCount - stack.count
    end

    return missingStock
end

return Inventory
