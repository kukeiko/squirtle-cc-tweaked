local getStacks = require "inventory.get-stacks"

---@param chest string
---@return table<string, integer>
return function(chest)
    ---@type table<string, integer>
    local stock = {}

    for _, item in pairs(getStacks(chest)) do
        stock[item.name] = (stock[item.name] or 0) + item.count
    end

    return stock
end
