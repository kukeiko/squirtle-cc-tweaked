local copy = require "utils.copy"

---@param stacks table<integer, ItemStack>
---@param keepCount? integer
---@return table<string, ItemStack>
return function(stacks, keepCount)
    keepCount = keepCount or 0
    ---@type table<string, ItemStack>
    local stock = {}

    for _, stack in pairs(stacks) do
        if not stock[stack.name] then
            stock[stack.name] = copy(stack)
            stock[stack.name].count = 0
            stock[stack.name].maxCount = 0
        end

        stock[stack.name].count = stock[stack.name].count + (stack.count - keepCount)
        stock[stack.name].maxCount = stock[stack.name].maxCount + (stack.maxCount - keepCount)
    end

    return stock
end
