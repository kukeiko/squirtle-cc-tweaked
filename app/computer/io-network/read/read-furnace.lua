local getStacks = require "inventory.get-stacks"
local Inventory = require "inventory.inventory"
local InputOutputInventory = require "inventory.input-output-inventory"

---@param name string
---@return InputOutputInventory
return function(name)
    local stacks = getStacks(name)
    local inputStack = stacks[1]
    local fuelStack = stacks[2]
    local outputStack = stacks[3]

    if not fuelStack then
        ---@type ItemStack
        fuelStack = {count = 0, maxCount = 64, name = "minecraft:charcoal"}
    end

    ---@type ItemStack[]
    local inputStacks = {inputStack, fuelStack}

    ---@type ItemStack[]
    local outputStacks = {nil, nil, outputStack}

    if outputStack then
        if inputStack then
            -- this makes sure that the input stack never gets empty
            outputStack.count = math.max(0, inputStack.count + outputStack.count - (outputStack.maxCount + 1))
        end
    end

    local input = Inventory.create(name, inputStacks)
    local output = Inventory.create(name, outputStacks)

    return InputOutputInventory.create(name, input, output, "furnace")
end
