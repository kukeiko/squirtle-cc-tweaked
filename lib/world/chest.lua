local copy = require "utils.copy"
local Peripheral = require "world.peripheral"
local Side = require "elements.side"
local findSide = require "world.chest.find-side"
local findInputOutputNameTagSlot = require "world.chest.find-io-name-tag-slot"
local getStacks = require "inventory.get-stacks"
local getSize = require "world.chest.get-size"
local subtractStock = require "world.chest.subtract-stock"
local getStock = require "world.chest.get-stock"

---@class Chest
---@field side integer
local Chest = {}

function Chest.findSide()
    return findSide()
end

---@param name string|integer
---@return integer
function Chest.getSize(name)
    if type(name) == "number" then
        return getSize(Side.getName(name))
    elseif type(name) == "string" then
        return getSize(name)
    end

    error("invalid arg")
end

---@param side string|integer
---@param slot integer
---@param detailed? boolean
---@return ItemStack
function Chest.getStack(side, slot, detailed)
    return Peripheral.call(side, "getItemDetail", slot, detailed)
end

---@param name string
---@param detailed? boolean
function Chest.getInputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local inputStacks = {}
    local stacks = getStacks(name)
    local nameTagSlot = findInputOutputNameTagSlot(name, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot < nameTagSlot then
                inputStacks[slot] = stack
            end
        end
    elseif Chest.getSize(name) > 27 then -- 2+ wide - assumed to be a storage chest (=> input)
        inputStacks = stacks
    end

    if detailed then
        for slot in pairs(inputStacks) do
            inputStacks[slot] = Chest.getStack(name, slot, true)
        end
    end

    return inputStacks
end

---@param name string
---@param detailed? boolean
function Chest.getOutputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}
    local stacks = getStacks(name)
    local nameTagSlot = findInputOutputNameTagSlot(name, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    elseif Chest.getSize(name) == 27 then -- 1 wide - assumed to be a autofarm chest (=> output)
        outputStacks = stacks
    end

    if detailed then
        for slot in pairs(outputStacks) do
            outputStacks[slot] = Chest.getStack(name, slot, true)
        end
    end

    return outputStacks
end

---@param name string
function Chest.getInputOutputStacks(name)
    -- [todo] optimize to only call chest.list() once
    local input = Chest.getInputStacks(name)
    local output = Chest.getOutputStacks(name)
    return input, output
end

---@param name string
---@return table<string, integer>
function Chest.getStock(name)
    if type(name) == "number" then
        return getStock(Side.getName(name))
    elseif type(name) == "string" then
        return getStock(name)
    end

    error("invalid arg")
end

---@param side string
---@param predicate string|function<boolean, ItemStack>
function Chest.getItemStock(side, predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(getStacks(side)) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param from string|integer
---@param to string|integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest.pushItems(from, to, fromSlot, limit, toSlot)
    if type(to) == "number" then
        to = Side.getName(to)
    end

    return Peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param from string|integer
---@param to string|integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest.pullItems(from, to, fromSlot, limit, toSlot)
    if type(to) == "number" then
        to = Side.getName(to)
    end

    return Peripheral.call(from, "pullItems", to, fromSlot, limit, toSlot)
end

---@param name string
---@return table<string, integer>
function Chest.getInputMaxStock(name)
    ---@type table<string, integer>
    local maxStock = {}

    for _, stack in pairs(Chest.getInputStacks(name, true)) do
        maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
    end

    return maxStock
end

---@param side string
function Chest.getInputOutputMaxStock(side)
    ---@type table<string, integer>
    local maxStock = {}

    for _, stack in pairs(Chest.getInputStacks(side, true)) do
        maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
    end

    for _, stack in pairs(Chest.getOutputStacks(side, true)) do
        maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
    end

    return maxStock
end

---@param name string
---@return table<string, integer>
function Chest.getOutputMissingStock(name)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Chest.getOutputStacks(name)) do
        stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
    end

    return stock
end

---@param name string
---@return table<string, integer>
function Chest.getInputMissingStock(name)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Chest.getInputStacks(name, true)) do
        stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
    end

    return stock
end

---@param side string
function Chest.countItems(side)
    local stock = Chest.getStock(side)
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock
    end

    return count
end

-- [todo] i have no better place yet for this method other than here, at Chest.
---@param a table<string, integer>
---@param b table<string, integer>
---@return table<string, integer>
function Chest.addStock(a, b)
    local result = copy(a)

    for item, stock in pairs(b) do
        result[item] = (result[item] or 0) + stock
    end

    return result
end

-- [todo] i have no better place yet for this method other than here, at Chest.
---@param a table<string, integer>
---@param b table<string, integer>
---@return table<string, integer>
function Chest.subtractStock(a, b)
    return subtractStock(a, b)
end

return Chest
