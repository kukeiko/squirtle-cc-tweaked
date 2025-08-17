local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local Inventory = require "lib.models.inventory"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local ItemApi = require "lib.apis.item-api"

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
---@param item string
---@param total integer
---@param options? TransferOptions
---@return integer transferredTotal
return function(from, to, item, total, options)
    if total <= 0 then
        return 0
    end

    options = options or {}
    local fromTag, toTag, rate = options.fromTag or "output", options.toTag or "input", options.rate or getDefaultRate()
    local lockSuccess, unlock, lockId = InventoryLocks.lock({from, to}, options.lockId)

    if not lockSuccess then
        return 0
    end

    local alreadyTransferred = 0

    local success, e = pcall(function()
        local fromInventory = InventoryCollection.get(from)
        local toInventory = InventoryCollection.get(to)
        local fromSlot, fromCount = Inventory.nextFromSlot(fromInventory, item, fromTag)
        local toSlot, toOpen = Inventory.nextToSlot(toInventory, item, toTag)

        while alreadyTransferred < total and fromSlot and fromCount and toSlot do
            if fromInventory.type == "storage" then
                -- refresh the inventory to prevent accidentally "deleting" storage stacks.
                -- bit of a hack, but currently no other idea on how else to fix it.
                -- this doesn't even completely fix it if a player manages to take out items after refresh and before pushItems()
                InventoryCollection.refresh({from}, lockId)
                fromInventory = InventoryCollection.get(from)
                fromSlot, fromCount = Inventory.nextFromSlot(fromInventory, item, fromTag)

                if not fromSlot or not fromCount then
                    break
                end
            end

            local open = total - alreadyTransferred
            local quantity = math.min(open, rate, fromCount, toOpen or fromCount)
            local transferred = InventoryPeripheral.transfer(from, to, fromSlot.index, quantity, toSlot.index)
            alreadyTransferred = alreadyTransferred + transferred

            if transferred ~= quantity then
                -- "from" and/or "to" inventory cache is no longer valid, refreshing both so that distributeItem() doesn't run in an endless loop
                print(string.format("[cache] invalidated: expected %d, transferred %d", quantity, transferred))
                InventoryCollection.mount({from, to})
                return
            end

            Inventory.removeItem(fromInventory, fromSlot.index, item, transferred)
            Inventory.addItem(toInventory, toSlot.index, item, transferred, ItemApi.getItemMaxCount(item, 64))
            fromSlot, fromCount = Inventory.nextFromSlot(fromInventory, item, fromTag)
            toSlot, toOpen = Inventory.nextToSlot(toInventory, item, toTag)
        end

        if alreadyTransferred > 0 then
            print(toPrintTransferString(from, to, item, alreadyTransferred))
        end
    end)

    if not success then
        print("[crash]", e)
    end

    unlock()

    return alreadyTransferred
end
