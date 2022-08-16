local copy = require "utils.copy"
local count = require "utils.count"
local getSize = require "world.chest.get-size"
local getStacks = require "world.chest.get-stacks"
local findInputOutputNameTagSlot = require "world.chest.find-io-name-tag-slot"

---@param stacks ItemStack[]
---@param keepCount? integer
---@return table<string, ItemStack>
local function stacksToStock(stacks, keepCount)
    keepCount = keepCount or 0
    ---@type table<string, ItemStack>
    local stock = {}

    for _, stack in pairs(stacks) do
        if not stock[stack.name] then
            stock[stack.name] = copy(stack)
            stock[stack.name].count = 0
            stock[stack.name].maxCount = 0
        end

        stock[stack.name].count = stock[stack.name].count + (stack.count - keepCount)
        stock[stack.name].maxCount = stock[stack.name].maxCount + (stack.maxCount - keepCount)
    end

    return stock
end

---@param chest string
---@return NetworkedChest
local function readOutputDumpChest(chest)
    local stacks = getStacks(chest)

    ---@type NetworkedChest
    local outputDumpChest = {
        name = chest,
        type = "output-dump",
        outputStacks = stacks,
        outputStock = stacksToStock(stacks)
    }

    return outputDumpChest
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return NetworkedChest
local function readNetworkedInputOutputChest(chest, stacks, nameTagSlot)
    ---@type NetworkedChest
    local ioChest = {name = chest, type = "io", inputStacks = {}, inputStock = {}, outputStacks = {}, outputStock = {}}

    -- [todo] use "stacksToStock(...)"
    for slot, stack in pairs(stacks) do
        if slot ~= nameTagSlot then
            local stacks = ioChest.inputStacks
            local stock = ioChest.inputStock

            if slot > nameTagSlot then
                stacks = ioChest.outputStacks
                stock = ioChest.outputStock
            end

            stack.count = stack.count - 1
            stack.maxCount = stack.maxCount - 1
            stacks[slot] = stack

            if not stock[stack.name] then
                stock[stack.name] = copy(stack)
            else
                local itemStock = stock[stack.name]
                itemStock.count = itemStock.count + stack.count
                itemStock.maxCount = itemStock.maxCount + stack.maxCount
            end
        end
    end

    return ioChest
end

---@param chest string
---@param stacks table<integer, ItemStack>
---@return NetworkedChest
local function readNetworkedStorageChest(chest, stacks)
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

    -- storageChest.inputStock = stacksToStock(storageChest.inputStacks, 1)

    -- if count(storageChest.inputStock) == 1 then
    --     for _, stack in pairs(storageChest.inputStock) do
    --         -- [todo] because we keep 1 @ "stacksToStock(..", the total maxCount is wrong.
    --         stack.maxCount = Chest.getSize(chest) * stack.maxCount
    --     end
    -- end

    return storageChest
end

-- [todo] this method is dirtily written. i just wanted it to work
---@param chest string
---@param assignedItems ItemStack[]
local function readAssignedChest(chest, assignedItems)
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

    ---@type NetworkedChest
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

---@param chests string[]
---@param barrel string
return function(chests, barrel)
    local barrelStacks = getStacks(barrel, true)
    ---@type table<string, ItemStack[]>
    local assigned = {}
    ---@type table<string, string>
    local dumps = {}

    for _, barrelStack in pairs(barrelStacks) do
        if barrelStack.name == "minecraft:chest" then
            dumps[barrelStack.displayName] = barrelStack.name
        else
            if not assigned[barrelStack.displayName] then
                assigned[barrelStack.displayName] = {}
            end

            table.insert(assigned[barrelStack.displayName], barrelStack)
        end
    end

    local networkedChests = {}

    print("reading", #chests, "networked chests...")

    for i, chest in ipairs(chests) do
        if i == math.ceil(#chests * .25) then
            print("25%")
        elseif i == math.ceil(#chests * .5) then
            print("50%")
        elseif i == math.ceil(#chests * .75) then
            print("75%")
        end

        if dumps[chest] then
            table.insert(networkedChests, readOutputDumpChest(chest))
        elseif assigned[chest] then
            -- if chest name is found in barrel, it is an assigned one, and I/O nametags are ignored.
            table.insert(networkedChests, readAssignedChest(chest, assigned[chest]))
        else
            local stacks = getStacks(chest)
            local nameTagSlot = findInputOutputNameTagSlot(chest, stacks)

            if nameTagSlot then
                -- if chest has I/O nametag, is io chest.
                table.insert(networkedChests, readNetworkedInputOutputChest(chest, stacks, nameTagSlot))
            else
                table.insert(networkedChests, readNetworkedStorageChest(chest, stacks))
            end
        end
    end

    print("100%")

    return networkedChests
end
