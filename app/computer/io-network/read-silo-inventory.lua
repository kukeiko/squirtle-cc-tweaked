local getStacks = require "inventory.get-stacks"
local stacksToStock = require "inventory.stacks-to-stock"

---@param chest string
---@param ignoredSlots? table<integer>
---@return NetworkedInventory
return function(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = getStacks(chest)

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    ---@type NetworkedInventory
    local drain = {
        name = chest,
        type = "silo",
        input = {name = chest, stacks = {}, stock = {}},
        output = {name = chest, stacks = stacks, stock = stacksToStock(stacks)}
    }

    return drain
end
