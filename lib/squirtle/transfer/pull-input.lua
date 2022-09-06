local Chest = require "world.chest"

---@param from string|integer
---@param to string|integer
---@param maxStock? table<string, integer>
---@return table<string, integer> transferredStock
return function(from, to, maxStock)
    maxStock = maxStock or Chest.getInputMaxStock(from)
    -- local maxStock = Chest.getInputOutputMaxStock(from)
    local currentStock = Chest.getStock(to)
    local missingStock = Chest.subtractStock(maxStock, currentStock)
    ---@type table<string, integer>
    local transferredStock = {}

    for slot, stack in pairs(Chest.getInputStacks(from)) do
        local stock = missingStock[stack.name]

        if stock ~= nil and stock > 0 then
            local limit = math.min(stack.count - 1, stock)
            local transferred = Chest.pullItems(to, from, slot, limit)
            missingStock[stack.name] = stock - transferred

            if transferred > 0 then
                transferredStock[stack.name] = (transferredStock[stack.name] or 0) + transferred
            end
        end
    end

    return transferredStock
end
