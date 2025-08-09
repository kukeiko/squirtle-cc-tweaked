local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@class QueuedInventoryUnlock
---@field lockId integer
---@field inventories string[]
---
---@class LockedInventory
---@field lockId integer
---@field count integer

local nextLockId = 1
---@type QueuedInventoryUnlock[]
local unlockQueue = {}
---@type table<string, LockedInventory>
local locks = {}
local pullingLockChangeCount = 0
local InventoryLocks = {}

local function getNextLockId()
    local lockId = nextLockId
    nextLockId = nextLockId + 1

    return lockId
end

---@param inventories string[]
---@param lockId integer
local function addLocks(inventories, lockId)
    for _, inventory in pairs(inventories) do
        if not locks[inventory] then
            locks[inventory] = {lockId = lockId, count = 1}
        else
            if locks[inventory].lockId ~= lockId then
                error("trying to increase lock count using a different lockId")
            end

            locks[inventory].count = locks[inventory].count + 1
        end
    end

    if pullingLockChangeCount > 0 then
        EventLoop.queue("inventory-locks:lock")
    end
end

---@param inventories string[]
local function removeLocks(inventories)
    for _, inventory in pairs(inventories) do
        locks[inventory].count = locks[inventory].count - 1

        if locks[inventory].count <= 0 then
            if locks[inventory].count < 0 then
                error("inventory lock count below zero")
            end

            locks[inventory] = nil
        end
    end
end

---@param inventories string[]
---@param lockId integer
local function isLocked(inventories, lockId)
    for _, inventory in pairs(inventories) do
        if locks[inventory] and locks[inventory].lockId ~= lockId then
            return true
        end
    end

    return false
end

---@param inventories string[]
---@param lockId integer
local function queue(inventories, lockId)
    ---@type QueuedInventoryUnlock
    local lock = {lockId = lockId, inventories = inventories}
    table.insert(unlockQueue, lock)
end

local function dequeue()
    local unlockIndex = Utils.findIndex(unlockQueue, function(item)
        return not isLocked(item.inventories, item.lockId)
    end)

    if unlockIndex then
        local lockId = unlockQueue[unlockIndex].lockId
        table.remove(unlockQueue, unlockIndex)
        EventLoop.queue("inventory-locks:unlock", lockId)
    end
end

---@param lockId integer
local function cancel(lockId)
    local index = Utils.findIndex(unlockQueue, function(item)
        return item.lockId == lockId
    end)

    if not lockId then
        error(string.format("lockId %d is not in queue", lockId))
    end

    table.remove(unlockQueue, index)
    EventLoop.queue("inventory-locks:cancel-unlock")
end

---@param lockId integer
local function awaitUnlock(lockId)
    while true do
        local _, pulledId = EventLoop.pull("inventory-locks:unlock")

        if pulledId == lockId then
            return
        end
    end
end

---@param inventories string[]
local function awaitDisconnect(inventories)
    while true do
        local _, name = EventLoop.pull("peripheral_detach")

        if Utils.indexOf(inventories, name) then
            return
        end
    end
end

---Suspends current coroutine until all given inventories could be locked. Inventories can only be locked if they are unlocked,
---or if their lock matches by the given lockId. Returns false if during waiting for unlock one or more inventories got detached.
---Unlock again by calling the returned unlock function. Share the lockId with other functions that might operate on the same inventories.
---@param inventories string[]
---@param lockId? integer
---@return boolean success, fun() : nil unlock, integer lockId
function InventoryLocks.lock(inventories, lockId)
    lockId = lockId or getNextLockId()

    while isLocked(inventories, lockId) do
        queue(inventories, lockId)
        local disconnected = false

        EventLoop.waitForAny(function()
            awaitDisconnect(inventories)
            disconnected = true
            cancel(lockId)
        end, function()
            awaitUnlock(lockId)
        end)

        if disconnected then
            return false, function()
            end, lockId
        end
    end

    addLocks(inventories, lockId)

    local releaseLocks = function()
        removeLocks(inventories)
        dequeue()
    end

    return true, releaseLocks, lockId
end

---@return string[]
function InventoryLocks.getLockedInventories()
    return Utils.getKeys(locks)
end

---@return string[]
function InventoryLocks.getInventoriesPendingUnlock()
    return Utils.flatMap(unlockQueue, function(item)
        return item.inventories
    end)
end

function InventoryLocks.pullLockChange()
    pullingLockChangeCount = pullingLockChangeCount + 1

    EventLoop.waitForAny(function()
        EventLoop.pull("inventory-locks:lock")
    end, function()
        EventLoop.pull("inventory-locks:unlock")
    end, function()
        EventLoop.pull("inventory-locks:cancel-unlock")
    end)

    pullingLockChangeCount = pullingLockChangeCount - 1
end

function InventoryLocks.clear()
    locks = {}
    unlockQueue = {}
    nextLockId = 1
end

return InventoryLocks
