local find = require "squirtle.backpack.find"
local selectSlot = require "squirtle.backpack.select-slot"

---@param name string
---@param exact? boolean
---@return false|integer
return function(name, exact)
    local slot = find(name, exact)

    if not slot then
        return false
    end

    selectSlot(slot)

    return slot
end
