local getStacks = require "world.chest.get-stacks"
local stacksToStock = require "io-network.stacks-to-stock"

---@param chest string
---@param ignoredSlots? table<integer>
---@return NetworkedChest
return function(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = getStacks(chest)

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    ---@type NetworkedChest
    local outputDumpChest = {
        name = chest,
        type = "output-dump",
        outputStacks = stacks,
        outputStock = stacksToStock(stacks)
    }

    return outputDumpChest
end
