local copy = require "utils.copy"
local count = require "utils.count"
local getSize = require "world.chest.get-size"
local stacksToStock = require "io-network.stacks-to-stock"

---@param chest string
---@param stacks table<integer, ItemStack>
---@return NetworkedChest
return function(chest, stacks)
    ---@type NetworkedChest
    local storageChest = {
        name = chest,
        type = "storage",
        inputStacks = {},
        inputStock = {},
        outputStacks = {},
        outputStock = {}
    }

    local items = {}

    for _, stack in pairs(stacks) do
        items[stack.name] = stack
    end

    -- [todo] ugly code
    if count(items) == 1 then
        local item

        for _, foo in pairs(items) do
            item = foo
        end

        for slot = 1, getSize(chest) do
            local stack = stacks[slot]

            if not stack then
                stacks[slot] = copy(item)
                stacks[slot].count = 0
            end
        end

        storageChest.inputStacks = stacks
        storageChest.inputStock = stacksToStock(stacks, 0)
    else
        for slot, stack in pairs(stacks) do
            storageChest.inputStacks[slot] = stack

            if not storageChest.inputStock[stack.name] then
                storageChest.inputStock[stack.name] = copy(stack)
            else
                local itemStock = storageChest.inputStock[stack.name]
                itemStock.count = itemStock.count + stack.count
                itemStock.maxCount = itemStock.maxCount + stack.maxCount
            end
        end

    end

    return storageChest
end
