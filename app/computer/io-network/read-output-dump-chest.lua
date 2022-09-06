local getStacks = require "world.chest.get-stacks"
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
    local outputDumpChest = {
        name = chest,
        type = "output-dump",
        outputStacks = stacks,
        outputStock = stacksToStock(stacks)
    }

    return outputDumpChest
end
