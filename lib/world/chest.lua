local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Side = require "elements.side"

---@class Chest
---@field side integer
local Chest = {}

local outputStart = 1
local outputEnd = 18
local inputStart = 19
local inputEnd = 27

function Chest.findSide(trapped)
    if trapped then
        return Peripheral.findSide("minecraft:trapped_chest")
    end

    return Peripheral.findSide("minecraft:chest")
end

---@param side integer
---@return Chest
function Chest.new(side)
    side = Side.fromArg(side)
    ---@type Chest
    local instance = {side = side}
    setmetatable(instance, {__index = Chest})
    return instance
end

--- [todo] not detailed. add flag?
---@param side string|integer
---@param slot integer
---@param detailed? boolean
---@return ItemStack
function Chest.getStack(side, slot, detailed)
    return Peripheral.call(side, "getItemDetail", slot, detailed)
end

---@param name string|integer
---@param detailed? boolean
---@return table<integer, ItemStack>
function Chest.getStacks(name, detailed)

    if not detailed then
        return Peripheral.call(name, "list")
    else
        local stacks = Peripheral.call(name, "list")
        ---@type table<integer, ItemStack>
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = Peripheral.call(name, "getItemDetail", slot)
        end

        return detailedStacks
    end
end

---@param name string|integer
---@param detailed? boolean
function Chest.getInputStacks(name, detailed)
    local stacks = Chest.getStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local inputStacks = {}

    for slot = inputStart, inputEnd do
        if stacks[slot] ~= nil then
            inputStacks[slot] = stacks[slot]
        end
    end

    return inputStacks
end

---@param name string|integer
---@param detailed? boolean
function Chest.getOutputStacks(name, detailed)
    local stacks = Chest.getStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}

    for slot = outputStart, outputEnd do
        if stacks[slot] ~= nil then
            outputStacks[slot] = stacks[slot]
        end
    end

    return outputStacks
end

---@param side integer
---@return table<string, integer>
function Chest.getStock(side)
    ---@type table<string, integer>
    local stock = {}

    for _, item in pairs(Chest.getStacks(side)) do
        stock[item.name] = (stock[item.name] or 0) + item.count
    end

    return stock
end

---@param side integer|string
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

    for _, stack in pairs(Chest.getStacks(side)) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

function Chest:getFirstInputSlot()
    -- [todo] hardcoded
    return 19
end

function Chest:getLastInputSlot()
    -- [todo] hardcoded
    return 27
end

function Chest:getFirstOutputSlot()
    -- [todo] hardcoded
    return 1
end

function Chest:getLastOutputSlot()
    -- [todo] hardcoded
    return 18
end

---@param from integer
---@param to integer
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

---@param from integer
---@param to integer
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

---@param name string|integer
---@return integer
function Chest.getSize(name)
    return Peripheral.call(name, "size")
end

---@param side integer
---@return table<string, integer>
function Chest.getInputMaxStock(side)
    local stacks = Chest.getStacks(side)
    ---@type table<string, integer>
    local maxStock = {}

    for slot = inputStart, inputEnd do
        if stacks[slot] ~= nil then
            local stack = Chest.getStack(side, slot)
            maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
        end
    end

    return maxStock
end

-- [todo] i have no better place yet for this method other than here, at Chest.
---@param a table<string, integer>
---@param b table<string, integer>
---@return table<string, integer>
function Chest.addStock(a, b)
    local result = Utils.copy(a)

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
    local result = Utils.copy(a)

    for item, stock in pairs(b) do
        result[item] = (result[item] or 0) - stock
    end

    return result
end

function Chest.getInputOutputMaxStock(side)
    local stacks = Chest.getStacks(side)
    ---@type table<string, integer>
    local maxStock = {}

    for slot = inputStart, inputEnd do
        if stacks[slot] ~= nil then
            local stack = Chest.getStack(side, slot)
            maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
        end
    end

    for slot = outputStart, outputEnd do
        if stacks[slot] ~= nil then
            local stack = Chest.getStack(side, slot)
            maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
        end
    end

    return maxStock
end

---@param side integer
---@return table<string, integer>
function Chest.getOutputMissingStock(side)
    local stacks = Chest.getStacks(side)
    ---@type table<string, integer>
    local stock = {}

    for slot = outputStart, outputEnd do
        if stacks[slot] ~= nil then
            local stack = Chest.getStack(side, slot)

            -- if stack.count < stack.maxCount then
            stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
            -- end
        end
    end

    return stock
end

---@param side integer
---@return table<string, integer>
function Chest.getInputMissingStock(side)
    local stacks = Chest.getStacks(side)
    ---@type table<string, integer>
    local stock = {}

    for slot = outputStart, outputEnd do
        if stacks[slot] ~= nil then
            local stack = Chest.getStack(side, slot)

            -- if stack.count < stack.maxCount then
            stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
            -- end
        end
    end

    return stock
end

function Chest.countItems(side)
    local stock = Chest.getStock(side)
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock
    end

    return count
end

return Chest
