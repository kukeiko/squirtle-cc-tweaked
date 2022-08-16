local getStacks = require "world.chest.get-stacks"
local findIoNameTagSlot = require "world.chest.find-io-name-tag-slot"

---@param chest string
---@return table<integer, ItemStack>, table<integer, ItemStack>
return function(chest)
    local stacks = getStacks(chest)
    local ioNameTagSlot = findIoNameTagSlot(chest, stacks)

    if not ioNameTagSlot then
        return {}, {}
    end

    local input = {}
    local output = {}

    for slot, stack in pairs(stacks) do
        if slot < ioNameTagSlot then
            input[slot] = stack
        elseif slot > ioNameTagSlot then
            output[slot] = stack
        end
    end

    return input, output
end
