---@param table table
local function shallowCopyTable(table)
    local copy = {}

    for k, v in pairs(table) do
        copy[k] = v
    end

    return copy
end

---@param source Chest
---@param target Chest
---@param maxStock table<string, integer>
return function(source, target, maxStock)
    local sourceItems = source:getDetailedItemList()
    local targetItems = target:getDetailedItemList()

    --- to prevent mutating input table
    maxStock = shallowCopyTable(maxStock)

    --- count up how much we already have in target
    for _, targetItem in pairs(targetItems) do
        if maxStock[targetItem.name] ~= nil then
            maxStock[targetItem.name] = maxStock[targetItem.name] - targetItem.count
        end
    end

    -- and then take items from output
    -- [todo] hardcoded output slot range
    for slot = source:getFirstOutputSlot(), source:getLastOutputSlot() do
        local sourceItem = sourceItems[slot]

        if sourceItem ~= nil then
            local maxStockForItem = maxStock[sourceItem.name]

            if maxStockForItem ~= nil and maxStockForItem > 0 then
                local numToTransfer = math.min(sourceItem.count - 1, maxStockForItem)
                local numTransferred = source:pushItems(target.side, slot, numToTransfer)
                maxStock[sourceItem.name] = maxStockForItem - numTransferred
            end
        end
    end
end
