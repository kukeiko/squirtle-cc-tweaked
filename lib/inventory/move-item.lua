local InventoryCollection = require "lib.inventory.inventory-collection"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory"

local function getDefaultRate()
    return 8
end

---@param name string
---@return string
local function removePrefix(name)
    local str = string.gsub(name, "minecraft:", "")
    return str
end

---@param from string
---@param to string
---@param item string
---@param transfer integer
local function toPrintTransferString(from, to, item, transfer)
    return string.format("%s > %s: %dx %s", removePrefix(from), removePrefix(to), transfer, removePrefix(item))
end

---@param from string
---@param to string
---@param fromSlot integer
---@param limit? integer
---@param toSlot? integer
---@return integer
local function pushItems(from, to, fromSlot, limit, toSlot)
    os.sleep(.25)
    return peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
end

---@param from string
---@param to string
---@param item string
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@param total integer
---@param rate? integer
---@return integer transferredTotal
return function(from, to, item, fromTag, toTag, total, rate)
    if total <= 0 then
        return 0
    end

    local unlock = InventoryCollection.lock(from, {from, to})
    local transferredTotal = 0
    rate = rate or getDefaultRate()

    local success, e = pcall(function()
        local fromInventory = InventoryCollection.get(from)
        local toInventory = InventoryCollection.get(to)
        local fromSlot, fromStack = Inventory.nextFromStack(fromInventory, item, fromTag)
        local toSlot = Inventory.nextToSlot(toInventory, item, toTag)

        while transferredTotal < total and fromSlot and fromStack and fromStack.count > 0 and toSlot do
            local open = total - transferredTotal
            local transfer = math.min(open, rate, fromStack.count)
            local transferred = pushItems(from, to, fromSlot.index, transfer, toSlot.index)

            if transferred == 0 then
                -- either the "from" or the "to" inventory cache is no longer valid. refreshing both so that distributeItem() doesn't run in an endless loop
                InventoryCollection.mount({from, to})
                return
            end

            transferredTotal = transferredTotal + transferred
            fromStack.count = fromStack.count - transferred

            if fromStack.count == 0 and not fromSlot.permanent then
                fromInventory.stacks[fromSlot.index] = nil
            end

            local toStack = toInventory.stacks[toSlot.index]

            if toStack then
                toStack.count = toStack.count + transferred
            else
                toInventory.stacks[toSlot.index] = InventoryPeripheral.getStack(to, toSlot.index)
            end

            if fromInventory.items then
                fromInventory.items[item] = fromInventory.items[item] - transferred
            end

            if toInventory.items then
                toInventory.items[item] = (toInventory.items[item] or 0) + transferred
            end

            fromSlot, fromStack = Inventory.nextFromStack(fromInventory, item, fromTag)
            toSlot = Inventory.nextToSlot(toInventory, item, toTag)
        end

        if transferredTotal > 0 then
            print(toPrintTransferString(from, to, item, transferredTotal))
        end
    end)

    if not success then
        print("[crash]", e)
    end

    unlock()

    return transferredTotal
end
