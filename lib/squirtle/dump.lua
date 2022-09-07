local Backpack = require "squirtle.backpack"
local drop = require "squirtle.drop"

---@param side string
---@return boolean success if everything could be dumped
return function(side)
    local items = Backpack.getStacks()

    for slot in pairs(items) do
        Backpack.selectSlot(slot)
        drop(side)
    end

    return Backpack.isEmpty()
end
