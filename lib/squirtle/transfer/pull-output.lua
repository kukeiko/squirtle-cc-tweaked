local Chest = require "world.chest"
local getStacks = require "inventory.get-stacks"

---@param table table
local function shallowCopyTable(table)
    local copy = {}

    for k, v in pairs(table) do
        copy[k] = v
    end

    return copy
end

---@param source string
---@param target string
---@param maxStock? table<string, integer>
return function(source, target, maxStock)
    maxStock = maxStock or {}
    local targetItems = getStacks(target, true)

    --- to prevent mutating input table
    maxStock = shallowCopyTable(maxStock)

    --- count up how much we already have in target
    for _, targetItem in pairs(targetItems) do
        if maxStock[targetItem.name] ~= nil then
            maxStock[targetItem.name] = maxStock[targetItem.name] - targetItem.count
        end
    end

    for slot, sourceItem in pairs(Chest.getOutputStacks(source, true)) do
        local maxStockForItem = maxStock[sourceItem.name]

        if maxStockForItem ~= nil and maxStockForItem > 0 then
            local numToTransfer = math.min(sourceItem.count - 1, maxStockForItem)
            local numTransferred = Chest.pushItems(source, target, slot, numToTransfer)
            maxStock[sourceItem.name] = maxStockForItem - numTransferred
        end
    end
end
