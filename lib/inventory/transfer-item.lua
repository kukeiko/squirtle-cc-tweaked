local Utils = require "lib.tools.utils"
local Inventory = require "lib.inventory.inventory"
local InventoryCollection = require "lib.inventory.inventory-collection"
local InventoryLocks = require "lib.inventory.inventory-locks"
local getTransferArguments = require "lib.inventory.get-transfer-arguments"
local moveItem = require "lib.inventory.move-item"

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
---@param lockId? integer
---@param except? string
---@return string inventory, fun() : nil unlock, integer lockId
local function lockNextInventory(inventories, lockId, except)
    for _, inventory in pairs(inventories) do
        if not InventoryLocks.isLocked({inventory}, lockId) and (not except or inventory ~= except) then
            local lockSuccess, unlock, lockId = InventoryLocks.lock({inventory}, lockId)

            if lockSuccess then
                return inventory, unlock, lockId
            end
        end
    end

    for _, inventory in pairs(inventories) do
        if not except or (inventory ~= except) then
            -- [todo] ❌ possible optimization: add InventoryLocks.lockAny(...) which will lock the first available
            local lockSuccess, unlock, lockId = InventoryLocks.lock({inventory}, lockId)

            if lockSuccess then
                return inventory, unlock, lockId
            end
        end
    end

    error("inventories table was empty")
end

---@param inventories string[]
---@param lockId? integer
---@param except? string
---@return fun() : string?, (fun() : nil)?, integer?
local function lockNext(inventories, lockId, except)
    local open = Utils.copy(inventories)

    return function()
        if #open == 0 or (except and #open == 1 and open[1] == except) then
            return
        end

        local inventory, unlock, lockId = lockNextInventory(open, lockId, except)
        Utils.remove(open, inventory)

        return inventory, unlock, lockId
    end
end

---@param from string[]
---@param to string[]
---@param item string
---@param total integer
---@param options TransferOptions
---@return integer
local function sequential(from, to, item, total, options)
    local open = total

    for _, fromInventory in ipairs(from) do
        for _, toInventory in ipairs(to) do
            open = open - moveItem(fromInventory, toInventory, item, open, options)

            if open == 0 then
                return total
            end
        end

        to = getToCandidates(to, item, options.toTag)
    end

    return total - open
end

---@param from string[]
---@param to string[]
---@param item string
---@param total integer
---@param options TransferOptions
---@return integer
local function sequentialDistribute(from, to, item, total, options)
    local open = total

    for _, fromInventory in ipairs(from) do
        while Inventory.canProvideItem(InventoryCollection.get(fromInventory), item, options.fromTag) and #to > 0 do
            local perInput = math.max(1, math.floor(open / #to))

            for toInventory, unlockTo, lockId in lockNext(to, options.lockId, fromInventory) do
                options.lockId = lockId
                open = open - moveItem(fromInventory, toInventory, item, perInput, options)
                unlockTo()

                if open == 0 then
                    return total
                end
            end

            to = getToCandidates(to, item, options.toTag)
        end
    end

    return total - open
end

---@param from string[]
---@param to string[]
---@param item string
---@param total integer
---@param options TransferOptions
---@return integer
local function distributeSequential(from, to, item, total, options)
    local open = total

    for _, toInventory in ipairs(to) do
        while Inventory.canTakeItem(InventoryCollection.get(toInventory), item, options.toTag) and #from > 0 do
            local available = InventoryCollection.getItemCount(from, item, options.fromTag)
            local perOutput = math.max(1, math.floor(math.min(open, available) / #from))

            for fromInventory, unlockFrom, lockId in lockNext(from, options.lockId, toInventory) do
                options.lockId = lockId
                open = open - moveItem(fromInventory, toInventory, item, perOutput, options)
                unlockFrom()

                if open == 0 then
                    return total
                end
            end

            from = getFromCandidates(from, item, options.toTag)
        end
    end

    return total - open
end

---@param from string[]
---@param to string[]
---@param item string
---@param total integer
---@param options TransferOptions
---@return integer transferred
local function distribute(from, to, item, total, options)
    local open = total

    while open > 0 and #from > 0 and #to > 0 do
        if #from == 1 and #to == 1 and from[1] == to[1] then
            break
        end

        local available = InventoryCollection.getItemCount(from, item, options.fromTag)
        local perOutput = math.min(open, available) / #from
        local perInput = math.max(1, math.floor(perOutput / #to))

        for fromInventory, unlockFrom, lockId in lockNext(from, options.lockId) do
            options.lockId = lockId

            for toInventory, unlockTo in lockNext(to, options.lockId, fromInventory) do
                open = open - moveItem(fromInventory, toInventory, item, perInput, options)
                unlockTo()

                if open == 0 then
                    break
                end
            end

            unlockFrom()
        end

        from = getFromCandidates(from, item, options.fromTag)
        to = getToCandidates(to, item, options.toTag)
    end

    return total - open
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
return function(from, to, item, quantity, options)
    local fromInventories, toInventories, options = getTransferArguments(from, to, options)
    local fromTag, toTag = options.fromTag, options.toTag

    if not fromTag then
        error("options.fromTag must be set")
    end

    if not toTag then
        error("options.toTag must be set")
    end

    fromInventories = getFromCandidates(fromInventories, item, fromTag)
    toInventories = getToCandidates(toInventories, item, toTag)
    local total = quantity or InventoryCollection.getItemCount(fromInventories, item, fromTag)

    if options.fromSequential and options.toSequential then
        return sequential(fromInventories, toInventories, item, total, options)
    elseif options.fromSequential then
        return sequentialDistribute(fromInventories, toInventories, item, total, options)
    elseif options.toSequential then
        return distributeSequential(fromInventories, toInventories, item, total, options)
    else
        return distribute(fromInventories, toInventories, item, total, options)
    end
end
