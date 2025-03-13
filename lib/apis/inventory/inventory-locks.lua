local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"

---@class InventoryLock
---@field id integer
---@field inventories string[]
---
---@class LockedInventory
---@field lockId integer
---@field count integer

local nextId = 1
---@type InventoryLock[]
local unlockQueue = {}
---@type table<string, LockedInventory>
local locks = {}

local InventoryLocks = {}

local function getNextLockId()
    local id = nextId
    nextId = nextId + 1
    return id
end

---@param inventories string[]
---@param lockId integer
local function addLocks(inventories, lockId)
    for _, inventory in pairs(inventories) do
        if not locks[inventory] then
            locks[inventory] = {lockId = lockId, count = 1}
        else
            locks[inventory].count = locks[inventory].count + 1
        end
    end
end

---@param inventories string[]
local function removeLocks(inventories)
    for _, inventory in pairs(inventories) do
        locks[inventory].count = locks[inventory].count - 1

        if locks[inventory].count == 0 then
            locks[inventory] = nil
        end
    end
end

---@param lockId? integer
---@param inventories string[]
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
    local lock = {id = lockId, inventories = inventories}
    table.insert(unlockQueue, lock)
end

local function dequeue()
    local unlockIndex = Utils.findIndex(unlockQueue, function(item)
        return not isLocked(item.inventories)
    end)

    if unlockIndex then
        local lockId = unlockQueue[unlockIndex].id
        table.remove(unlockQueue, unlockIndex)
        EventLoop.queue("inventory-locks:unlock", lockId)
    end
end

---@param id integer
local function cancel(id)
    local index = Utils.findIndex(unlockQueue, function(item)
        return item.id == id
    end)

    if not id then
        error(string.format("id %d is not in queue", id))
    end

    table.remove(unlockQueue, index)
end

---@param id integer
local function awaitUnlock(id)
    while true do
        local _, pulledId = EventLoop.pull("inventory-locks:unlock")

        if pulledId == id then
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

    if isLocked(inventories, lockId) then
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

function InventoryLocks.clear()
    locks = {}
    unlockQueue = {}
    nextId = 1
end

return InventoryLocks
