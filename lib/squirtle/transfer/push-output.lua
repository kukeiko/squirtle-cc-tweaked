local Chest = require "world.chest"

---@param from integer
---@param to integer
---@param keepStock? table<string, integer>
---@return boolean pushedAll if everything could be pushed
return function(from, to, keepStock)
    keepStock = keepStock or {}
    local missingStock = Chest.getOutputMissingStock(to)
    local availableStock = Chest.subtractStock(Chest.getStock(from), keepStock)

    ---@type table<string, integer>
    local pushableStock = {}

    for item, missing in pairs(missingStock) do
        local available = availableStock[item]

        if available ~= nil and available > 0 then
            pushableStock[item] = math.min(missing, available)
        end
    end

    local outputStacks = Chest.getOutputStacks(to, true)

    for slot, stack in pairs(Chest.getStacks(from)) do
        local stock = pushableStock[stack.name]

        if stock ~= nil and stock > 0 then
            for outputSlot, outputStack in pairs(outputStacks) do
                if outputStack.name == stack.name and outputStack.count < outputStack.maxCount and stack.count > 0 and
                    pushableStock[stack.name] > 0 then
                    local transfer = math.min(pushableStock[stack.name], outputStack.maxCount - outputStack.count)
                    local transferred = Chest.pushItems(from, to, slot, transfer, outputSlot)
                    outputStack.count = outputStack.count + transferred
                    stack.count = stack.count - transferred
                    pushableStock[stack.name] = pushableStock[stack.name] - transferred
                end
            end
        end
    end

    local remainingStock = Chest.subtractStock(Chest.getStock(from), keepStock)

    for item, stock in pairs(remainingStock) do
        if missingStock[item] and stock > 0 then
            return false
        end
    end

    return true
end
