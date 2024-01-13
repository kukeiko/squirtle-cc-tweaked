local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"

---@param name string
---@return InputOutputInventory
return function(name)
    local stacks = Inventory.getStacks(name)
    local inputStack = stacks[1]
    local fuelStack = stacks[2]
    local outputStack = stacks[3]

    ---@type ItemStack[]
    local inputStacks = {inputStack, fuelStack}

    ---@type ItemStack[]
    local outputStacks = {nil, nil, outputStack}

    local input = Inventory.create(name, inputStacks, false)
    local output = Inventory.create(name, outputStacks)

    return InputOutputInventory.create(name, input, output, "furnace")
end
