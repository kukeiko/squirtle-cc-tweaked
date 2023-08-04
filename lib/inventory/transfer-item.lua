local pushItems = require "world.chest.push-items"
local getDefaultRate = require "inventory.get-default-rate"
local copy = require "utils.copy"
local getSize = require "inventory.get-size"

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer? slot, ItemStack? stack
local function nextFromStack(stacks, item)
    for slot, stack in pairs(stacks) do
        if stack.count > 0 and stack.name == item then
            return slot, stack
        end
    end
end

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer? slot, ItemStack? stack
local function nextToStack(stacks, item, sample, size)
    for slot, stack in pairs(stacks) do
        if stack.count < stack.maxCount and stack.name == item then
            return slot, stack
        end
    end
end

---@param inventory Inventory
---@param sample ItemStack
---@return integer? slot, ItemStack? stack
local function allocateNextToStack(inventory, sample)
    -- [todo] doesn't work with i/o inventories - it doesn't have to currently, but still.
    local size = getSize(inventory.name)
    for slot = 1, size do
        local stack = inventory.stacks[slot]

        if not stack then
            ---@type ItemStack
            stack = copy(sample)
            stack.count = 0
            inventory.stacks[slot] = stack

            local stock = inventory.stock[sample.name]

            if not stock then
                ---@type ItemStack
                stock = copy(sample)
                stock.count = 0
                stock.maxCount = 0
                inventory.stock[sample.name] = stock
            end

            stock.maxCount = stock.maxCount + sample.maxCount

            return slot, inventory.stacks[slot]
        end
    end
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param total integer
---@param rate? integer
---@param allowAllocate? boolean
---@return integer transferredTotal
return function(from, to, item, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    local transferredTotal = 0
    local fromSlot, fromStack = nextFromStack(from.stacks, item)
    local fromStock = from.stock[item]
    local toSlot, toStack = nextToStack(to.stacks, item)

    if not toSlot and allowAllocate and fromStack then
        toSlot, toStack = allocateNextToStack(to, fromStack)
    end

    local toStock = to.stock[item]

    while transferredTotal < total and fromSlot and fromStack and toSlot and toStack do
        local space = toStack.maxCount - toStack.count
        local stock = fromStack.count
        local open = total - transferredTotal
        local transfer = math.min(space, open, rate, stock)
        local transferred = pushItems(from.name, to.name, fromSlot, transfer, toSlot)
        os.sleep(.5)

        fromStack.count = fromStack.count - transferred
        fromStock.count = fromStock.count - transferred

        toStack.count = toStack.count + transferred
        toStock.count = toStock.count + transferred

        transferredTotal = transferredTotal + transferred

        if transferred ~= transfer then
            -- [todo] if i ever decide to not abort, but continue, then i need to flag the current toSlot
            -- to be ignored, otherwise we'll have an endless loop
            print("transferred amount not as expected")
            return transferredTotal
        end

        fromSlot, fromStack = nextFromStack(from.stacks, item)
        toSlot, toStack = nextToStack(to.stacks, item)

        if not toSlot and allowAllocate and fromStack then
            toSlot, toStack = allocateNextToStack(to, fromStack)
        end
    end

    return transferredTotal
end
