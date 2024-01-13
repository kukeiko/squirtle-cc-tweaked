local Utils = require "utils"
local InventoryElemental = require "inventory.inventory-elemental"
local InventoryBasic = require "inventory.inventory-basic"

-- [note] refuel numbers not actually used
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@class InventoryAdvanced:InventoryBasic
local InventoryAdvanced = {}
setmetatable(InventoryAdvanced, {__index = InventoryBasic})

local function getDefaultRate()
    return 8
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
local function allocateNextFurnaceToStack(inventory, sample)
    if fuelItems[sample.name] and not inventory.stacks[2] then
        -- local fuelStack = inventory.stacks[2] -- [todo] what? we just checked for "not inventory.stacks[2]"

        local fuelStack = Utils.clone(sample)
        fuelStack.count = 0
        inventory.stacks[2] = fuelStack

        if not inventory.stock[sample.name] then
            inventory.stock[sample.name] = Utils.clone(sample)
            inventory.stock[sample.name].count = 0
        end

        return 2, fuelStack
    elseif not inventory.stacks[1] then
        local stack = Utils.clone(sample)
        stack.count = 0
        inventory.stacks[1] = stack

        if not inventory.stock[sample.name] then
            inventory.stock[sample.name] = Utils.clone(sample)
            inventory.stock[sample.name].count = 0
        end

        return 1, stack
    end
end

---@param inventory Inventory
---@param sample ItemStack
---@return integer? slot, ItemStack? stack
local function allocateNextToStack(inventory, sample)
    if InventoryBasic.isFurnace(inventory) then
        return allocateNextFurnaceToStack(inventory, sample)
    end

    if #inventory.slots > 0 then
        for _, slot in pairs(inventory.slots) do
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

                -- [todo] i think this screws up lava bucket transfer
                stock.maxCount = stock.maxCount + sample.maxCount

                return slot, inventory.stacks[slot]
            end
        end
    else
        -- [todo] doesn't work with i/o inventories - it doesn't have to currently, but still.
        local size = InventoryElemental.getSize(inventory.name)

        for slot = 1, size do
            local stack = inventory.stacks[slot]

            if not stack then
                ---@type ItemStack
                stack = Utils.copy(sample)
                stack.count = 0
                inventory.stacks[slot] = stack

                local stock = inventory.stock[sample.name]

                if not stock then
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
end

---@param name string
---@return string
local function removePrefix(name)
    local str = string.gsub(name, "minecraft:", "")
    return str
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param transfer integer
local function toPrintTransferString(from, to, item, transfer)
    return string.format("%s > %s: %dx %s", removePrefix(from.name), removePrefix(to.name), transfer, removePrefix(item))
end

---@param from Inventory
---@param to Inventory
---@param item string
---@param total? integer
---@param rate? integer
---@param allowAllocate? boolean
---@return integer transferredTotal
function InventoryAdvanced.transferItem(from, to, item, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    if not total then
        if not from.stock[item] then
            return 0
        end

        total = from.stock[item].count
    end

    -- print(toPrintTransferString(from, to, item, total))
    allowAllocate = allowAllocate or InventoryBasic.isFurnace(to)

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
        local transferred = InventoryElemental.pushItems(from.name, to.name, fromSlot, transfer, toSlot)

        -- [todo] should we not remove the stack & stock completely once it is 0,
        -- so that the data state is the same as if we've read the inventory after transferring all?
        -- [todo] consider extracting stack/stock manipulation into a separate method
        fromStack.count = fromStack.count - transferred
        fromStock.count = fromStock.count - transferred
        toStack.count = toStack.count + transferred
        toStock.count = toStock.count + transferred

        -- [todo] consider moving the transfer rate timeout directly to pushItems()
        os.sleep(.5)

        transferredTotal = transferredTotal + transferred

        if transferred ~= transfer then
            print(toPrintTransferString(from, to, item, transferredTotal))

            return transferredTotal
        end

        fromSlot, fromStack = nextFromStack(from.stacks, item)
        toSlot, toStack = nextToStack(to.stacks, item)

        if not toSlot and allowAllocate and fromStack then
            toSlot, toStack = allocateNextToStack(to, fromStack)
        end
    end

    print(toPrintTransferString(from, to, item, transferredTotal))

    return transferredTotal
end

---@param from Inventory
---@param to Inventory
---@param total table<string, integer>
---@param rate? integer
---@param allowAllocate? boolean
---@return table<string, integer> transferred
function InventoryAdvanced.transferItems(from, to, total, rate, allowAllocate)
    rate = rate or getDefaultRate()

    ---@type table<string, integer>
    local transferredTotal = {}

    for item, itemTotal in pairs(total) do
        local transferred = InventoryAdvanced.transferItem(from, to, item, itemTotal, rate, allowAllocate)

        if transferred > 0 then
            transferredTotal[item] = transferred
        end
    end

    return transferredTotal
end

return InventoryAdvanced
