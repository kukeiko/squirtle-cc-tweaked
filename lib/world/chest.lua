local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Side = require "elements.side"

---@class Chest
---@field side integer
local Chest = {}

local chestTypes = {"minecraft:chest", "minecraft:trapped_chest"}

---@param name string|integer
---@param stacks table<integer, ItemStack>
---@return integer? slot
local function findInputOutputNameTagSlot(name, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = Chest.getStack(name, slot, true)

            if stack.displayName == "I/O" then
                return slot
            end
        end
    end
end

function Chest.findSide()
    return Peripheral.findSide(chestTypes)
end

---@param types string|string[]
function Chest.isChestType(types)
    if type(types) == "string" then
        types = {types}
    end

    for i = 1, #types do
        if Utils.indexOf(chestTypes, types[i]) > 0 then
            return true
        end
    end

    return false
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

---@param name string|integer
---@return integer
function Chest.getSize(name)
    return Peripheral.call(name, "size")
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
    ---@type table<integer, ItemStack>
    local inputStacks = {}
    local stacks = Chest.getStacks(name)
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

---@param name string|integer
---@param detailed? boolean
function Chest.getOutputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}
    local stacks = Chest.getStacks(name)
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

---@param name string|integer
---@return table<string, integer>
function Chest.getStock(name)
    ---@type table<string, integer>
    local stock = {}

    for _, item in pairs(Chest.getStacks(name)) do
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
---@return table<string, integer>
function Chest.getInputMaxStock(name)
    ---@type table<string, integer>
    local maxStock = {}

    for _, stack in pairs(Chest.getInputStacks(name, true)) do
        maxStock[stack.name] = (maxStock[stack.name] or 0) + stack.maxCount
    end

    return maxStock
end

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

---@param name string|integer
---@return table<string, integer>
function Chest.getOutputMissingStock(name)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Chest.getOutputStacks(name, true)) do
        stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
    end

    return stock
end

---@param name string|integer
---@return table<string, integer>
function Chest.getInputMissingStock(name)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Chest.getInputStacks(name, true)) do
        stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
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

return Chest
