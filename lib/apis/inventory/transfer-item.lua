local Utils = require "lib.tools.utils"
local Inventory = require "lib.models.inventory"
local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local getTransferArguments = require "lib.apis.inventory.get-transfer-arguments"
local moveItem = require "lib.apis.inventory.move-item"

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getFromCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canProvideItem(InventoryCollection.get(name), item, tag)
    end)
end

---@param names string[]
---@param item string
---@param tag InventorySlotTag
---@return string[] candidates
local function getToCandidates(names, item, tag)
    return Utils.filter(names, function(name)
        return InventoryCollection.isMounted(name) and Inventory.canTakeItem(InventoryCollection.get(name), item, tag)
    end)
end

---@param inventories string[]
---@param unlockedFirst? boolean
---@param lockId? integer
---@return fun() : string?
local function inventories(inventories, unlockedFirst, lockId)
    if unlockedFirst then
        ---@type table<string, true>
        local returned = {}

        return function()
            for i, inventory in pairs(inventories) do
                if not returned[inventory] and not InventoryLocks.isLocked({inventory}, lockId) then
                    returned[inventory] = true
                    return inventory
                end
            end

            for i, inventory in pairs(inventories) do
                if not returned[inventory] then
                    returned[inventory] = true
                    return inventory
                end
            end
        end
    else
        local i = 1

        return function()
            local inventory = inventories[i]
            i = i + 1
            return inventory
        end
    end
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
return function(from, to, item, quantity, options)
    local fromInventories, toInventories, options = getTransferArguments(from, to, options)
    local fromTag, toTag = options.fromTag --[[@as InventorySlotTag]] , options.toTag --[[@as InventorySlotTag]]
    fromInventories = getFromCandidates(fromInventories, item, fromTag)
    toInventories = getToCandidates(toInventories, item, toTag)
    local total = quantity or InventoryCollection.getItemCount(fromInventories, item, fromTag)
    local totalTransferred = 0

    while totalTransferred < total and #fromInventories > 0 and #toInventories > 0 do
        if #fromInventories == 1 and #toInventories == 1 and fromInventories[1] == toInventories[1] then
            break
        end

        local transferPerOutput = (total - totalTransferred)

        if not options.fromSequential then
            transferPerOutput = transferPerOutput / #fromInventories
        end

        local transferPerInput = math.max(1, math.floor(transferPerOutput))

        if not options.toSequential then
            transferPerInput = math.max(1, math.floor(transferPerOutput / #toInventories))
        end

        --- [todo] ⏰ in regards to locking/unlocking:
        --- previously, before the rewrite, we were sorting based on lock-state, i.e. take inventories first that are not locked.
        --- we really should have that functionality again to make sure the system is not super slow in some cases
        --- [idea] first of all, we can only sort the fromInventories if fromSequential is false, and toInventories only if toSequential is false.
        --- then we could create a custom iterator that will return the first unlocked inventory (which it won't ever return in subsequent calls)
        --- in the case of fromInventories, we should then immediately lock it so we keep access to it while moving items to the toInventories
        for fromInventory in inventories(fromInventories, not options.fromSequential, options.lockId) do
            local lockSuccess, unlock, lockId = InventoryLocks.lock({fromInventory}, options.lockId)
            options.lockId = lockId

            if not lockSuccess and options.fromSequential then
                return 0
            end

            for toInventory in inventories(toInventories, not options.toSequential, options.lockId) do
                if fromInventory ~= toInventory then
                    local transferred = moveItem(fromInventory, toInventory, item, transferPerInput, options)
                    totalTransferred = totalTransferred + transferred

                    if totalTransferred == total then
                        unlock()
                        return totalTransferred
                    end
                end
            end

            unlock()
        end

        fromInventories = getFromCandidates(fromInventories, item, fromTag)
        toInventories = getToCandidates(toInventories, item, toTag)
    end

    return totalTransferred
end
