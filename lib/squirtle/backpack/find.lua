local getSize = require "squirtle.backpack.get-size"
local getStack = require "squirtle.backpack.get-stack"

---@param name string
---@param exact? boolean
return function(name, exact)
    for slot = 1, getSize() do
        local item = getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and string.find(item.name, name) then
            return slot
        end
    end
end
