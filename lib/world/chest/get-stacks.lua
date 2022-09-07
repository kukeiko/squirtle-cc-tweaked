local Side = require "elements.side"
local getStacks = require "inventory.get-stacks"

-- [todo] remove in favor of world.chest.get-stacks,
-- difference is that this still supports "name" to be an integer
---@param name string|integer
---@param detailed? boolean
---@return table<integer, ItemStack>
return function(name, detailed)
    if type(name) == "number" then
        return getStacks(Side.getName(name), detailed)
    elseif type(name) == "string" then
        return getStacks(name, detailed)
    else
        error("arg error", name)
    end
end
