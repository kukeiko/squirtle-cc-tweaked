local stacksToStock = require "io-network.stacks-to-stock"
local copy = require "utils.copy"

---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return table<integer, ItemStack>, table<integer, ItemStack>
local function toInputOutputStacks(stacks, nameTagSlot)
    local inputStacks = {}
    local outputStacks = {}

    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            ---@type ItemStack
            local stack = copy(stack)
            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1

            if slot < nameTagSlot then
                inputStacks[slot] = stack
            elseif slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    end

    return inputStacks, outputStacks
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return NetworkedInventory
return function(chest, stacks, nameTagSlot)
    local inputStacks, outputStacks = toInputOutputStacks(stacks, nameTagSlot)

    ---@type NetworkedInventory
    local ioChest = {
        name = chest,
        type = "io",
        inputStacks = inputStacks,
        inputStock = stacksToStock(inputStacks),
        outputStacks = outputStacks,
        outputStock = stacksToStock(outputStacks)
    }

    return ioChest
end
