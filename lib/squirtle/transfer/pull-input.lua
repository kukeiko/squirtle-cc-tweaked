local Chest = require "world.chest"

---@param from integer
---@param to integer
return function(from, to)
    local maxStock = Chest.getInputMaxStock(from)
    local currentStock = Chest.getStock(to)
    local missingStock = Chest.subtractStock(maxStock, currentStock)

    for slot, stack in pairs(Chest.getInputStacks(from)) do
        local stock = missingStock[stack.name]

        if stock ~= nil and stock > 0 then
            local limit = math.min(stack.count - 1, stock)
            local transferred = Chest.pullItems(to, from, slot, limit)
            missingStock[stack.name] = stock - transferred
        end
    end
end
