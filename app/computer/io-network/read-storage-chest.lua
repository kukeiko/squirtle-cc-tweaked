local copy = require "utils.copy"
local count = require "utils.count"
local stacksToStock = require "inventory.stacks-to-stock"
local getSize = require "inventory.get-size"

---@param chest string
---@param stacks table<integer, ItemStack>
---@return NetworkedInventory
return function(chest, stacks)
    ---@type NetworkedInventory
    local storageChest = {
        name = chest,
        type = "storage",
        input = {name = chest, stacks = {}, stock = {}},
        output = {name = chest, stacks = {}, stock = {}}
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

        storageChest.input.stacks = stacks
        storageChest.input.stock = stacksToStock(stacks)
    else
        for slot, stack in pairs(stacks) do
            storageChest.input.stacks[slot] = stack

            if not storageChest.input.stock[stack.name] then
                storageChest.input.stock[stack.name] = copy(stack)
            else
                local itemStock = storageChest.input.stock[stack.name]
                itemStock.count = itemStock.count + stack.count
                itemStock.maxCount = itemStock.maxCount + stack.maxCount
            end
        end

    end

    return storageChest
end
