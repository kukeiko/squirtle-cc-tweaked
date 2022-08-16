local getOutputMissingStock = require "world.chest.get-output-missing-stock"
local getOutputStacks = require "world.chest.get-output-stacks"
local getStacks = require "world.chest.get-stacks"
local getStock = require "world.chest.get-stock"
local pushItems = require "world.chest.push-items"
local subtractStock = require "world.chest.subtract-stock"

---@param stock table<string, integer>
---@param missingStock table<string, integer>
---@param keepStock? table<string, integer>
local function calculatePushableStock(stock, missingStock, keepStock)
    keepStock = keepStock or {}
    ---@type table<string, integer>
    local pushableStock = {}
    local availableStock = subtractStock(stock, keepStock)

    for item, missing in pairs(missingStock) do
        local available = availableStock[item]

        if available ~= nil and available > 0 then
            pushableStock[item] = math.min(missing, available)
        end
    end

    return pushableStock
end

---@param from string
---@param to string
---@param stacks table<integer, ItemStack>
---@param outputStacks table<integer, ItemStack>
---@param pushableStock table<string, integer>
local function transferPushableStock(from, to, stacks, outputStacks, pushableStock)
    local transferredStock = {}

    for slot, stack in pairs(stacks) do
        local stock = pushableStock[stack.name]

        if stock ~= nil and stock > 0 then
            for outputSlot, outputStack in pairs(outputStacks) do
                if outputStack.name == stack.name and outputStack.count < outputStack.maxCount and stack.count > 0 and
                    pushableStock[stack.name] > 0 then
                    local transfer = math.min(pushableStock[stack.name], outputStack.maxCount - outputStack.count)
                    local transferred = pushItems(from, to, slot, transfer, outputSlot)
                    outputStack.count = outputStack.count + transferred
                    stack.count = stack.count - transferred
                    pushableStock[stack.name] = pushableStock[stack.name] - transferred
                    transferredStock[stack.name] = (transferredStock[stack.name] or 0) + transferred
                end
            end
        end
    end

    return transferredStock
end

-- [todo] keepStock is not used yet anywhere; but i want to keep it because it should (imo)
-- be used @ lumberjack to push birch-saplings, but make sure to always keep at least 32
---@param from string
---@param to string
---@param keepStock? table<string, integer>
---@return boolean, table<string, integer>
return function(from, to, keepStock)
    keepStock = keepStock or {}
    local missingStock = getOutputMissingStock(to)
    local pushableStock = calculatePushableStock(getStock(from), missingStock, keepStock)
    local transferred = transferPushableStock(from, to, getStacks(from), getOutputStacks(to), pushableStock)
    local remainingStock = subtractStock(getStock(from), keepStock)

    for item, stock in pairs(remainingStock) do
        if missingStock[item] and stock > 0 then
            return false, transferred
        end
    end

    return true, transferred
end
