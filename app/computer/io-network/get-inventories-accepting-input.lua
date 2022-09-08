local indexOf = require "utils.index-of"

---@param inventories NetworkedInventory[]
---@param ignore NetworkedInventory[]
---@param item string
---@return NetworkedInventory[]
return function(inventories, ignore, item)
    local others = {}

    for _, candidate in ipairs(inventories) do
        local stock = candidate.input.stock[item];

        if stock and stock.count < stock.maxCount and indexOf(ignore, candidate.name) < 1 then
            table.insert(others, candidate)
        end
    end

    return others
end
