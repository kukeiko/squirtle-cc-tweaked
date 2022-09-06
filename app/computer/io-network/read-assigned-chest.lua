local getSize = require "world.chest.get-size"
local getStacks = require "world.chest.get-stacks"
local stacksToStock = require "inventory.stacks-to-stock"

-- [todo] this method is dirtily written. i just wanted it to work
---@param chest string
---@param assignedItems ItemStack[]
return function(chest, assignedItems)
    local stacks = getStacks(chest)
    local stock = stacksToStock(stacks)
    local size = getSize(chest)
    ---@type table<string, ItemStack>
    local targetStock = {}

    -- [todo] a bit weird to have to keep track of item maxCount separately
    ---@type table<string, integer>
    local itemMaxCount = {}

    for _, assignedStack in ipairs(assignedItems) do
        local slots = math.floor(size / #assignedItems)
        local assignedStock = targetStock[assignedStack.name]

        if not assignedStock then
            itemMaxCount[assignedStack.name] = assignedStack.maxCount
            assignedStock = {name = assignedStack.name, count = 0, maxCount = 0}
            targetStock[assignedStack.name] = assignedStock
        end

        assignedStock.maxCount = assignedStock.maxCount + (slots * itemMaxCount[assignedStack.name])
        assignedStock.count = assignedStock.maxCount
    end

    -- [todo] maybe instead of manipulating targetStock, make a new variable
    for item, itemStock in pairs(stock) do
        if targetStock[item] then
            targetStock[item].count = targetStock[item].count - itemStock.maxCount
            -- else
            --     targetStock[item] = {name = itemStock.name, count = itemStock.count, maxCount = itemStock.maxCount}
        end
    end

    for slot = 1, size do
        local stack = stacks[slot]

        if not stack then
            for item, itemStock in pairs(targetStock) do
                if itemStock.count > 0 then
                    itemStock.count = itemStock.count - itemMaxCount[item]
                    stacks[slot] = {name = itemStock.name, count = 0, maxCount = itemMaxCount[item]}
                    -- stacks[slot].count = 0
                    -- stacks[slot].maxCount = itemMaxCount[item]
                    break
                end
            end
        end
    end

    ---@type NetworkedInventory
    local assignedChest = {
        name = chest,
        type = "assigned",
        inputStacks = stacks,
        -- inputStock = targetStock,
        inputStock = stacksToStock(stacks),
        outputStacks = {},
        outputStock = {}
    }

    return assignedChest
end
