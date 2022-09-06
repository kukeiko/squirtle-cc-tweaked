local getStack = require "world.chest.get-stack"
local indexOf = require "utils.index-of"

---@param chest string
---@param tagNames table<string>
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
return function(chest, tagNames, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = getStack(chest, slot, true)

            if indexOf(tagNames, stack.displayName) then
                return slot, stack.displayName
            end
        end
    end
end
