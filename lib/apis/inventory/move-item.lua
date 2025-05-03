local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local Inventory = require "lib.models.inventory"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"

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
    local transferred = peripheral.call(from, "pushItems", to, fromSlot, limit, toSlot)
    os.sleep(.25)

    return transferred
end

---@param from string
---@param to string
---@param item string
---@param fromTag InventorySlotTag
---@param toTag InventorySlotTag
---@param total integer
---@param rate? integer
---@param lockId? integer
---@return integer transferredTotal
return function(from, to, item, fromTag, toTag, total, rate, lockId)
    if total <= 0 then
        return 0
    end

    local lockSuccess, unlock, lockId = InventoryLocks.lock({from, to}, lockId)

    if not lockSuccess then
        return 0
    end

    local transferredTotal = 0
    rate = rate or getDefaultRate()

    local success, e = pcall(function()
        local fromInventory = InventoryCollection.get(from)
        local toInventory = InventoryCollection.get(to)
        local fromSlot, fromStack = Inventory.nextFromStack(fromInventory, item, fromTag)
        local toSlot, toStack = Inventory.nextToStack(toInventory, item, toTag)

        while transferredTotal < total and fromSlot and fromStack and toSlot do
            if fromInventory.type == "storage" then
                -- refresh the inventory to prevent accidentally "deleting" storage stacks.
                -- bit of a hack, but currently no other idea on how else to fix it.
                -- this doesn't even completely fix it if a player manages to take out items after refresh and before pushItems()
                InventoryCollection.refresh({from}, lockId)
                fromInventory = InventoryCollection.get(from)
                fromSlot, fromStack = Inventory.nextFromStack(fromInventory, item, fromTag)

                if not fromSlot or not fromStack or fromStack.count == 0 then
                    break
                end
            end

            local open = total - transferredTotal
            local toStackOpenCount = fromStack.count

            if toStack then
                toStackOpenCount = toStack.maxCount - toStack.count
            end

            local quantity = math.min(open, rate, fromStack.count, toStackOpenCount)
            local transferred = pushItems(from, to, fromSlot.index, quantity, toSlot.index)
            transferredTotal = transferredTotal + transferred

            if transferred ~= quantity then
                -- either the "from" or the "to" inventory cache is no longer valid. refreshing both so that distributeItem() doesn't run in an endless loop
                print(string.format("[cache] invalidated: expected %d, transferred %d", quantity, transferred))
                InventoryCollection.mount({from, to})
                return
            end

            fromInventory.items[item] = fromInventory.items[item] - transferred
            fromStack.count = fromStack.count - transferred

            if fromStack.count == 0 and not fromSlot.permanent then
                fromInventory.stacks[fromSlot.index] = nil
            end

            if toStack then
                toStack.count = toStack.count + transferred
                toInventory.items[item] = (toInventory.items[item] or 0) + transferred
            else
                -- can be nil in case of hoppers
                toStack = InventoryPeripheral.getStack(to, toSlot.index)

                if toStack then
                    toInventory.stacks[toSlot.index] = toStack
                    toInventory.items[item] = (toInventory.items[item] or 0) + toStack.count
                end
            end

            fromSlot, fromStack = Inventory.nextFromStack(fromInventory, item, fromTag)
            toSlot, toStack = Inventory.nextToStack(toInventory, item, toTag)
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
