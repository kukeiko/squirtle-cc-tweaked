local getOutputStacks = require "world.chest.get-output-stacks"

---@param chest string
---@return table<string, integer>
return function(chest)
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(getOutputStacks(chest)) do
        stock[stack.name] = (stock[stack.name] or 0) + (stack.maxCount - stack.count)
    end

    return stock
end
