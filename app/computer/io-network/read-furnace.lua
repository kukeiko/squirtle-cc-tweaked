local stacksToStock = require "inventory.stacks-to-stock"
local getStacks = require "inventory.get-stacks"

---@param name string
---@return NetworkedInventory
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
            outputStack.count = math.max(0, inputStack.count + outputStack.count - (outputStack.maxCount + 1))
        end
    end

    ---@type NetworkedInventory
    local inventory = {
        name = name,
        type = "furnace",
        input = {name = name, stacks = inputStacks, stock = stacksToStock(inputStacks)},
        output = {name = name, stacks = outputStacks, stock = stacksToStock(outputStacks)}
    }

    return inventory
end
