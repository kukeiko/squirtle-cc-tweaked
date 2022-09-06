local getSize = require "squirtle.backpack.get-size"
local getStack = require "squirtle.backpack.get-stack"

-- [todo] idea: cache stacks until any event is pulled.
-- that should - afaik - be completely safe, as any change in turtle inventory triggers a "turtle_inventory" event
---@return ItemStack[]
return function()
    local stacks = {}

    for slot = 1, getSize() do
        local item = getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end
