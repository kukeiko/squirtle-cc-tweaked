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

        if newQuantity > 0 then
            added[item] = newQuantity
        end
    end

    return added
end

return {subtract = subtract, add = add}
