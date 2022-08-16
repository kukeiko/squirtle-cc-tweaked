local Inventory = require "squirtle.inventory"
local drop = require "squirtle.drop"

---@param side integer|string
---@return boolean success if everything could be dumped
return function(side)
    local items = Inventory.list()

    for slot in pairs(items) do
        Inventory.selectSlot(slot)
        drop(side)
    end

    return Inventory.isEmpty()
end
