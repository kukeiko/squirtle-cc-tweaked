local find = require "squirtle.backpack.find"
local selectSlot = require "squirtle.backpack.select-slot"

---@param name string
return function(name)
    local slot = find(name)

    if not slot then
        return false
    end

    selectSlot(slot)

    return slot
end
