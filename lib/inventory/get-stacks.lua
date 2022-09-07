local getItemMaxCount = require "inventory.get-item-max-count"

---@param name string
---@param detailed? boolean
---@return table<integer, ItemStack>
return function(name, detailed)
    if not detailed then
        ---@type table<integer, ItemStack>
        local stacks = peripheral.call(name, "list")

        for slot, stack in pairs(stacks) do
            stack.maxCount = getItemMaxCount(stack.name, name, slot)
        end

        return stacks
    else
        local stacks = peripheral.call(name, "list")
        ---@type table<integer, ItemStack>
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = peripheral.call(name, "getItemDetail", slot)
        end

        return detailedStacks
    end
end
