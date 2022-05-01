local pushItems = require "world.chest.push-items"

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer slot, ItemStack stack
local function nextOutputStack(stacks, item)
    for slot, stack in pairs(stacks) do
        if stack.count > 0 and stack.name == item then
            return slot, stack
        end
    end
end

---@param stacks table<integer, ItemStack>
---@param item string
---@return integer slot, ItemStack stack
local function nextInputStack(stacks, item)
    for slot, stack in pairs(stacks) do
        if stack.count < stack.maxCount and stack.name == item then
            return slot, stack
        end
    end
end

---@param from NetworkedChest
---@param to NetworkedChest
---@param item string
---@param total integer
---@param rate integer
---@return integer transferredTotal
return function(from, to, item, total, rate)
    local transferredTotal = 0
    local fromSlot, fromStack = nextOutputStack(from.outputStacks, item)
    local toSlot, toStack = nextInputStack(to.inputStacks, item)

    while transferredTotal < total and fromSlot and toSlot do
        local space = toStack.maxCount - toStack.count
        local stock = fromStack.count
        local open = total - transferredTotal
        local transfer = math.min(space, open, rate, stock)
        local transferred = pushItems(from.name, to.name, fromSlot, transfer, toSlot)
        os.sleep(.5)

        if transferred ~= transfer then
            -- [todo] if i ever decide to not abort, but continue, then i need to flag the current toSlot
            -- to be ignored, otherwise we'll have an endless loop
            print("transferred amount not as expected")
            return transferredTotal
        end

        fromStack.count = fromStack.count - transferred
        toStack.count = toStack.count + transferred
        transferredTotal = transferredTotal + transferred
        fromSlot, fromStack = nextOutputStack(from.outputStacks, item)
        toSlot, toStack = nextInputStack(to.inputStacks, item)
    end

    return transferredTotal
end
