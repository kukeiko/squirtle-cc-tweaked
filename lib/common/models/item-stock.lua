local Utils = require "lib.common.utils";

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

return {subtract = subtract, add = add, merge = merge, isEmpty = isEmpty}
