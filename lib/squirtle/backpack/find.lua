local getSize = require "squirtle.backpack.get-size"
local getStack = require "squirtle.backpack.get-stack"

---@param name string
---@param exact? boolean
---@return integer?
return function(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, getSize() do
        local item = getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end
