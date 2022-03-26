local Utils = require "utils"
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

    for slot, stack in pairs(Chest.getStacks(from)) do
        local stock = pushableStock[stack.name]

        if stock ~= nil and stock > 0 then
            local transferred = Chest.pushItems_V2(from, to, slot, stock)
            pushableStock[stack.name] = stock - transferred

            -- if pushableStock[stack.name] <= 0 then
            --     pushableStock[stack.name] = nil
            -- end
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
