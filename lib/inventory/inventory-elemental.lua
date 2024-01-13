local Utils = require "utils"

---@class InventoryElemental
local InventoryElemental = {}

---@param chest string
---@return integer
function InventoryElemental.getSize(chest)
    return peripheral.call(chest, "size")
end

---@param inventory Inventory
function InventoryElemental.isEmpty(inventory)
    for _, stack in pairs(inventory.stacks) do
        if stack and stack.count > 0 then
            return false
        end
    end

    return true
end

---@param a ItemStock
---@param b ItemStock
---@return ItemStock
function InventoryElemental.subtractStock(a, b)
    local result = Utils.clone(a)

    for item, stock in pairs(b) do
        result[item].count = (result[item].count) - stock.count
    end

    return result
end

---@param side string
---@param slot integer
---@return ItemStack
function InventoryElemental.getStack(side, slot)
    return peripheral.call(side, "getItemDetail", slot)
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function InventoryElemental.pushItems(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function InventoryElemental.pullItems(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pullItems", to, fromSlot, limit, toSlot)
end

---@param furnace Inventory
---@return ItemStack?
function InventoryElemental.getFurnaceInputStack(furnace)
    return furnace.stacks[1]
end

---@param furnace Inventory
---@return ItemStack?
function InventoryElemental.getFurnaceFuelStack(furnace)
    return furnace.stacks[2]
end

---@param furnace Inventory
---@return ItemStack?
function InventoryElemental.getFurnaceOutputStack(furnace)
    return furnace.stacks[3]
end

---@param stocks ItemStock[]
---@return ItemStock
function InventoryElemental.mergeStocks(stocks)
    ---@type ItemStock
    local merged = {}

    for _, stock in pairs(stocks) do
        for item, itemStock in pairs(stock) do
            local mergedStock = merged[item]

            if not mergedStock then
                merged[item] = Utils.copy(itemStock)
            else
                mergedStock.count = mergedStock.count + itemStock.count
                mergedStock.maxCount = mergedStock.maxCount + itemStock.maxCount
            end
        end
    end

    return merged
end

return InventoryElemental
