local getInputOutputStacks = require "world.chest.get-input-output-stacks"

---@param chest string
return function(chest)
    local _, output = getInputOutputStacks(chest)

    return output
end
