local Utils = require "utils"
local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"

---@param chest string
---@param ignoredSlots? table<integer>
---@return InputOutputInventory
return function(chest, ignoredSlots)
    ignoredSlots = ignoredSlots or {}
    local stacks = Inventory.getStacks(chest, true)

    local nameTag, nameTagSlot = Utils.find(stacks, function(item)
        return item.name == "minecraft:name_tag" and item.displayName == "Furnace: Input"
    end)

    if not nameTag or not nameTagSlot then
        error("failed to find furnace input name tag")
    end

    stacks[nameTagSlot] = nil

    for slot in pairs(ignoredSlots) do
        stacks[slot] = nil
    end

    local input = Inventory.create(chest, {})
    local output = Inventory.create(chest, stacks)

    return InputOutputInventory.create(chest, input, output, "furnace-input")
end
