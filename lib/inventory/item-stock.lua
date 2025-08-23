local Utils = require "lib.tools.utils";

---@alias ItemStock table<string, integer>
---
---@param what ItemStock
---@param by ItemStock
local function subtract(what, by)
    ---@type ItemStock
    local subtracted = {}

    for item, quantity in pairs(what) do
        local newQuantity = quantity - (by[item] or 0)

        if newQuantity > 0 then
            subtracted[item] = newQuantity
        end
    end

    return subtracted
end

---@param what ItemStock
---@param with ItemStock
---@return ItemStock
local function add(what, with)
    ---@type ItemStock
    local added = Utils.copy(what)

    for item, quantity in pairs(with) do
        local newQuantity = quantity + (added[item] or 0)
        added[item] = newQuantity
    end

    return added
end

---@param stocks ItemStock[]
---@return ItemStock
local function merge(stocks)
    ---@type ItemStock
    local merged = {}

    for _, stock in pairs(stocks) do
        merged = add(merged, stock)
    end

    return merged
end

---@param what ItemStock
---@param with ItemStock
---@return ItemStock
local function intersect(what, with)
    ---@type ItemStock
    local intersected = {}

    for item, quantity in pairs(what) do
        if with[item] then
            intersected[item] = quantity
        end
    end

    return intersected
end

---@param stock ItemStock
---@return boolean
local function isEmpty(stock)
    for _, quantity in pairs(stock) do
        if quantity > 0 then
            return false
        end
    end

    return true
end

---@param a ItemStock
---@param b ItemStock
---@return boolean
local function isEqual(a, b)
    for item, quantity in pairs(a) do
        if b[item] ~= quantity then
            return false
        end
    end

    for item, quantity in pairs(b) do
        if a[item] ~= quantity then
            return false
        end
    end

    return true
end

---@param stacks ItemStacks
---@param ignoredSlots? integer[]
---@return ItemStock
local function fromStacks(stacks, ignoredSlots)
    ---@type ItemStock
    local stock = {}

    for slot, stack in pairs(stacks) do
        if not ignoredSlots or not Utils.indexOf(ignoredSlots, slot) then
            stock[stack.name] = (stock[stack.name] or 0) + stack.count
        end
    end

    return stock
end

return {subtract = subtract, add = add, merge = merge, isEmpty = isEmpty, fromStacks = fromStacks, isEqual = isEqual, intersect = intersect}
