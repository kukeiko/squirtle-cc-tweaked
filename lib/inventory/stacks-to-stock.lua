local copy = require "utils.copy"

---@param stacks table<integer, ItemStack>
---@return table<string, ItemStack>
return function(stacks)
    ---@type table<string, ItemStack>
    local stock = {}

    for _, stack in pairs(stacks) do
        local itemStock = stock[stack.name]

        if not itemStock then
            itemStock = copy(stack)
            itemStock.count = 0
            itemStock.maxCount = 0
            stock[stack.name] = itemStock
        end

        itemStock.count = itemStock.count + stack.count
        itemStock.maxCount = itemStock.maxCount + stack.maxCount
    end

    return stock
end
