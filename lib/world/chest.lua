local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Side = require "elements.side"
local DetailedItemStack = require "world.detailed-item-stack"
local ItemStack = require "world.item-stack"

---@class Chest
---@field side integer
local Chest = {}

local outputStart = 1
local outputEnd = 18
local inputStart = 19
local inputEnd = 27

function Chest.findSide()
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
---@param side integer
---@param slot integer
---@param detailed? boolean
---@return ItemStackV2
function Chest.getStack(side, slot, detailed)
    return Peripheral.call(side, "getItemDetail", slot, detailed)
end

---@param side integer
---@return table<integer, ItemStackV2>
function Chest.getStacks(side)
    return Peripheral.call(side, "list")
end

--- [todo] not detailed. add flag?
---@param side integer
function Chest.getInputStacks(side)
    local stacks = Chest.getStacks(side)
    ---@type table<integer, ItemStackV2>
    local inputStacks = {}

    for slot = inputStart, inputEnd do
        if stacks[slot] ~= nil then
            inputStacks[slot] = stacks[slot]
        end
    end

    return inputStacks
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
---@param predicate string|function<boolean, ItemStackV2>
function Chest.getItemStock(side, predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStackV2
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

---@return ItemStack[]
function Chest:getItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type ItemStack[]
    local list = {}

    for slot, nativeItem in pairs(nativeList) do
        list[slot] = ItemStack.cast(nativeItem)
    end

    return list
end

---@return DetailedItemStack[]
function Chest:getDetailedItemList()
    local nativeList = Peripheral.call(self.side, "list")
    ---@type DetailedItemStack[]
    local list = {}

    for slot, _ in pairs(nativeList) do
        local nativeItem = Peripheral.call(self.side, "getItemDetail", slot);

        if (nativeItem == nil) then
            error("slot #" .. slot .. " unexpectedly empty")
        end

        list[slot] = DetailedItemStack.cast(nativeItem)
    end

    return list
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

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest:pushItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pushItems", Side.getName(target), fromSlot, limit, toSlot)
end

---@param from integer
---@param to integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest.pushItems_V2(from, to, fromSlot, limit, toSlot)
    return Peripheral.call(from, "pushItems", Side.getName(to), fromSlot, limit, toSlot)
end

---@param target integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest:pullItems(target, fromSlot, limit, toSlot)
    return Peripheral.call(self.side, "pullItems", Side.getName(target), fromSlot, limit, toSlot)
end

---@param from integer
---@param to integer
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Chest.pullItems_V2(from, to, fromSlot, limit, toSlot)
    return Peripheral.call(from, "pullItems", Side.getName(to), fromSlot, limit, toSlot)
end

---@return integer
function Chest:getSize()
    return Peripheral.call(self.side, "size")
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

function Chest.countItems(side)
    local stock = Chest.getStock(side)
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock
    end

    return count
end

return Chest
