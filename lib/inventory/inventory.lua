local Utils = require "utils"
local findSide = require "world.peripheral.find-side"

---@param stacks table<integer, ItemStack>
---@return table<string, ItemStack>
local function stacksToStock(stacks)
    ---@type table<string, ItemStack>
    local stock = {}

    for _, stack in pairs(stacks) do
        local itemStock = stock[stack.name]

        if not itemStock then
            itemStock = Utils.copy(stack)
            itemStock.count = 0
            itemStock.maxCount = 0
            stock[stack.name] = itemStock
        end

        itemStock.count = itemStock.count + stack.count
        itemStock.maxCount = itemStock.maxCount + stack.maxCount
    end

    return stock
end

---@type table<string, integer>
local itemMaxCounts = {}

local function getDefaultRate()
    return 8
end

---@class Inventory
---@field name string
---@field stock ItemStock
---@field stacks ItemStacks
---@field locked boolean

local Inventory = {}

---@param name string
---@param stacks? ItemStacks
---@param detailed? boolean
---@return Inventory
function Inventory.create(name, stacks, detailed)
    stacks = stacks or Inventory.getStacks(name, detailed)

    ---@type Inventory
    local inventory = {name = name, stacks = stacks, stock = stacksToStock(stacks), locked = false}

    return inventory
end

---@param item string
---@param chest string
---@param slot integer
function Inventory.getItemMaxCount(item, chest, slot)
    if not itemMaxCounts[item] then
        ---@type ItemStack|nil
        local detailedStack = peripheral.call(chest, "getItemDetail", slot)

        if detailedStack then
            itemMaxCounts[item] = detailedStack.maxCount
        end
    end

    return itemMaxCounts[item]
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function Inventory.getStacks(name, detailed)
    if not detailed then
        ---@type ItemStacks
        local stacks = peripheral.call(name, "list")

        for slot, stack in pairs(stacks) do
            stack.maxCount = Inventory.getItemMaxCount(stack.name, name, slot)
        end

        return stacks
    else
        local stacks = peripheral.call(name, "list")
        ---@type ItemStacks
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = peripheral.call(name, "getItemDetail", slot)
        end

        return detailedStacks
    end
end

---@param name string
---@return ItemStock
function Inventory.getStock(name)
    return stacksToStock(Inventory.getStacks(name))
end

---@param name string
---@return ItemStock
function Inventory.getInputStock(name)
    return stacksToStock(Inventory.getInputStacks(name, true))
end

---@return string?
function Inventory.findChest()
    return findSide("minecraft:chest")
end

---@param chest string
---@return integer
function Inventory.getSize(chest)
    return peripheral.call(chest, "size")
end

---@param name string
function Inventory.countItems(name)
    local stock = stacksToStock(Inventory.getStacks(name))
    local count = 0

    for _, itemStock in pairs(stock) do
        count = count + itemStock.count
    end

    return count
end

---@param side string
---@param predicate string|function<boolean, ItemStack>
---@return integer
function Inventory.getItemStock(side, predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Inventory.getStacks(side)) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param a ItemStock
---@param b ItemStock
---@return ItemStock
function Inventory.subtractStock(a, b)
    local result = Utils.clone(a)

    for item, stock in pairs(b) do
        result[item].count = (result[item].count) - stock.count
    end

    return result
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function Inventory.getInputStacks(name, detailed)
    ---@type ItemStacks
    local inputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = Inventory.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot < nameTagSlot then
                inputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) > 27 then -- 2+ wide - assumed to be a storage chest (=> input)
        inputStacks = stacks
    end

    if detailed then
        for slot in pairs(inputStacks) do
            inputStacks[slot] = Inventory.getStack(name, slot, true)
        end
    end

    return inputStacks
end

---@param side string
---@param slot integer
---@param detailed? boolean
---@return ItemStack
function Inventory.getStack(side, slot, detailed)
    return peripheral.call(side, "getItemDetail", slot, detailed)
end

---@param name string
---@param tagNames table<string>
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
function Inventory.findNameTag(name, tagNames, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = Inventory.getStack(name, slot, true)

            if Utils.indexOf(tagNames, stack.displayName) then
                return slot, stack.displayName
            end
        end
    end
end

---@param name string
---@param detailed? boolean
function Inventory.getOutputStacks(name, detailed)
    ---@type table<integer, ItemStack>
    local outputStacks = {}
    local stacks = Inventory.getStacks(name)
    local nameTagSlot = Inventory.findNameTag(name, {"I/O"}, stacks)

    if nameTagSlot then
        for slot, stack in pairs(stacks) do
            if slot > nameTagSlot then
                outputStacks[slot] = stack
            end
        end
    elseif Inventory.getSize(name) == 27 then -- 1 wide - assumed to be a autofarm chest (=> output)
        outputStacks = stacks
    end

    if detailed then
        for slot in pairs(outputStacks) do
            outputStacks[slot] = Inventory.getStack(name, slot, true)
        end
    end

    return outputStacks
end

---@param name string
---@return table<string, integer>
function Inventory.getOutputMissingStock(name)
    ---@type table<string, integer>
    local missingStock = {}
    local stock = stacksToStock(Inventory.getOutputStacks(name))

    for item, stack in pairs(stock) do
        missingStock[item] = stack.maxCount - stack.count
    end

    return missingStock
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Inventory.pushItems(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param inventory string
---@param fromSlot integer
---@param toSlot? integer
---@param quantity? integer
---@return integer
function Inventory.move(inventory, fromSlot, toSlot, quantity)
    os.sleep(.5) -- [note] exists on purpose, as I don't want turtles to move items too quickly in suckSlot()
    return Inventory.pushItems(inventory, inventory, fromSlot, quantity, toSlot)
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
function Inventory.pullItems(from, to, fromSlot, limit, toSlot)
    return peripheral.call(from, "pullItems", to, fromSlot, limit, toSlot)
end

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
    local size = Inventory.getSize(inventory.name)
    for slot = 1, size do
        local stack = inventory.stacks[slot]

        if not stack then
            ---@type ItemStack
            stack = Utils.copy(sample)
            stack.count = 0
            inventory.stacks[slot] = stack

            local stock = inventory.stock[sample.name]

            if not stock then
                ---@type ItemStack
                stock = Utils.copy(sample)
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
function Inventory.transferItem(from, to, item, total, rate, allowAllocate)
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
        local transferred = Inventory.pushItems(from.name, to.name, fromSlot, transfer, toSlot)

        fromStack.count = fromStack.count - transferred
        fromStock.count = fromStock.count - transferred
        toStack.count = toStack.count + transferred
        toStock.count = toStock.count + transferred

        os.sleep(.5)

        transferredTotal = transferredTotal + transferred

        if transferred ~= transfer then
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

---@param from Inventory
---@param to Inventory
---@param total table<string, integer>
---@param rate? integer
---@param allowAllocate? boolean
---@return table<string,integer> transferred
function Inventory.transferItems(from, to, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    ---@type table<string, integer>
    local transferredTotal = {}

    for item, itemTotal in pairs(total) do
        local transferred = Inventory.transferItem(from, to, item, itemTotal, rate, allowAllocate)

        if transferred > 0 then
            transferredTotal[item] = transferred
        end
    end

    return transferredTotal
end

return Inventory
