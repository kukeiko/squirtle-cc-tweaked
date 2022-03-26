local Chest = require "world.chest"

---@param table table
local function shallowCopyTable(table)
    local copy = {}

    for k, v in pairs(table) do
        copy[k] = v
    end

    return copy
end

---@param source integer
---@param target integer
---@param maxStock table<string, integer>
return function(source, target, maxStock)
    local targetItems = Chest.getStacks(target, true)

    --- to prevent mutating input table
    maxStock = shallowCopyTable(maxStock)

    --- count up how much we already have in target
    for _, targetItem in pairs(targetItems) do
        if maxStock[targetItem.name] ~= nil then
            maxStock[targetItem.name] = maxStock[targetItem.name] - targetItem.count
        end
    end

    -- and then take items from output
    local sourceItems = Chest.getStacks(source, true)
    local sourceInstance = Chest.new(source)

    for slot = sourceInstance:getFirstOutputSlot(), sourceInstance:getLastOutputSlot() do
        local sourceItem = sourceItems[slot]

        if sourceItem ~= nil then
            local maxStockForItem = maxStock[sourceItem.name]

            if maxStockForItem ~= nil and maxStockForItem > 0 then
                local numToTransfer = math.min(sourceItem.count - 1, maxStockForItem)
                local numTransferred = Chest.pushItems(source, target, slot, numToTransfer)
                maxStock[sourceItem.name] = maxStockForItem - numTransferred
            end
        end
    end
end
