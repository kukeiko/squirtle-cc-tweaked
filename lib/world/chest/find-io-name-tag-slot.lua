local getStack = require "world.chest.get-stack"

---@param name string|integer
---@param stacks table<integer, ItemStack>
---@return integer? slot
return function(name, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = getStack(name, slot, true)

            if stack.displayName == "I/O" then
                return slot
            end
        end
    end
end
