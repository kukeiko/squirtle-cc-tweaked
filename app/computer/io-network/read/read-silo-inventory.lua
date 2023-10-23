local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
return function(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = Inventory.getStacks(chest)

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = Inventory.create(chest, {})
    local output = Inventory.create(chest, stacks)

    return InputOutputInventory.create(chest, input, output, "silo")
end
