local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.models.item-stock"
local Inventory = require "lib.models.inventory"
local InventoryReader = require "lib.apis.inventory.inventory-reader"
local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
local DatabaseApi = require "lib.apis.database.database-api"
local moveItem = require "lib.apis.inventory.move-item"
local ItemApi = require "lib.apis.item-api"

---@class InventoryApi
local InventoryApi = {}

---@param handle InventoryHandle
---@return string[]
local function resolveHandle(handle)
    if type(handle) == "number" then
        return InventoryApi.resolveBuffer(handle)
    elseif type(handle) == "string" then
        return {InventoryApi.getByTypeAndLabel("stash", handle)}
    else
        return handle --[[@as table<string>]]
    end
end

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

---@param type InventoryType
function InventoryApi.refresh(type)
    local inventories = InventoryApi.getByType(type)
    InventoryCollection.refresh(inventories)
end

---@param inventories InventoryHandle
function InventoryApi.refreshInventories(inventories)
    InventoryCollection.refresh(resolveHandle(inventories))
end

---@return string[]
function InventoryApi.getAll()
    return Utils.map(InventoryCollection.getAll(), function(item)
        return item.name
    end)
end

---@param type InventoryType
---@return string[]
function InventoryApi.getByType(type)
    local inventories = InventoryCollection.getByType(type)

    return Utils.map(inventories, function(item)
        return item.name
    end)
end

---@param type InventoryType
---@return string[]
function InventoryApi.getRefreshedByType(type)
    InventoryApi.refresh(type)
    return InventoryApi.getByType(type)
end

---@param inventoryType InventoryType
---@param label string
---@return string
function InventoryApi.getByTypeAndLabel(inventoryType, label)
    return InventoryCollection.getByTypeAndLabel(inventoryType, label).name
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getSlotCount(inventories, tag)
    return InventoryCollection.getSlotCount(inventories, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemCount(inventories, item, tag)
    return InventoryCollection.getItemCount(inventories, item, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getTotalItemCount(inventories, tag)
    return InventoryCollection.getTotalItemCount(inventories, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemMaxCount(inventories, item, tag)
    return InventoryCollection.getItemMaxCount(inventories, item, tag)
end

---@param inventories string[]
---@param item string
---@param tag InventorySlotTag
---@return integer
function InventoryApi.getItemOpenCount(inventories, item, tag)
    return InventoryCollection.getItemOpenCount(inventories, item, tag)
end

---@param inventories string[]
---@param tag? InventorySlotTag
---@return ItemStock
function InventoryApi.getStock(inventories, tag)
    return InventoryCollection.getStock(inventories, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getMaxStock(inventories, tag)
    return InventoryCollection.getMaxStock(inventories, tag)
end

---@param inventories string[]
---@param tag InventorySlotTag
---@return ItemStock
function InventoryApi.getOpenStock(inventories, tag)
    return InventoryCollection.getOpenStock(inventories, tag)
end

---@param handle InventoryHandle
---@return boolean
local function isBufferHandle(handle)
    return type(handle) == "number"
end

---@param handle InventoryHandle
---@return InventoryType?
local function getTypeByHandle(handle)
    if type(handle) == "number" then
        return "buffer"
    elseif type(handle) == "string" then
        return "stash"
    end

    return nil
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultFromOptions(type, options)
    if type == "buffer" and options.fromSequential == nil then
        options.fromSequential = true
    end

    if options.fromTag == nil then
        if type == "buffer" or type == "stash" then
            options.fromTag = "buffer"
        else
            options.fromTag = "output"
        end
    end

    return options
end

---@param type InventoryType?
---@param options TransferOptions
---@return TransferOptions
local function getDefaultToOptions(type, options)
    if type == "buffer" and options.toSequential == nil then
        options.toSequential = true
    end

    if options.toTag == nil then
        if type == "buffer" or type == "stash" then
            options.toTag = "buffer"
        else
            options.toTag = "input"
        end
    end

    return options
end

---@param handle InventoryHandle
---@param options? TransferOptions
---@return string[] inventories, TransferOptions options
local function getToHandleTransferArguments(handle, options)
    local type = getTypeByHandle(handle)

    return resolveHandle(handle), getDefaultToOptions(type, options or {})
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param options? TransferOptions
---@return string[] from, string[] to, TransferOptions options
local function getTransferArguments(from, to, options)
    local fromType = getTypeByHandle(from)
    local toType = getTypeByHandle(to)
    local options = getDefaultFromOptions(fromType, options or {})
    options = getDefaultToOptions(toType, options)

    return resolveHandle(from), resolveHandle(to), options
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
local function transferItem(from, to, item, quantity, options)
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

        --- [todo] ❌ in regards to locking/unlocking:
        --- previously, before the rewrite, we were sorting based on lock-state, i.e. take inventories first that are not locked.
        --- we really should have that functionality again to make sure the system is not super slow in some cases
        for _, fromName in ipairs(fromInventories) do
            for _, toName in ipairs(toInventories) do
                if fromName ~= toName then
                    local transferred = moveItem(fromName, toName, item, fromTag, toTag, transferPerInput, options.rate, options.lockId)
                    totalTransferred = totalTransferred + transferred

                    if totalTransferred == total then
                        return totalTransferred
                    end
                end
            end
        end

        fromInventories = getFromCandidates(fromInventories, item, fromTag)
        toInventories = getToCandidates(toInventories, item, toTag)
    end

    return totalTransferred
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
function InventoryApi.transferItem(from, to, item, quantity, options)
    return transferItem(from, to, item, quantity, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param items ItemStock
---@param options? TransferOptions
---@return boolean transferredAll, ItemStock transferred, ItemStock open
local function transferStock(from, to, items, options)
    ---@type ItemStock
    local transferredTotal = {}
    ---@type ItemStock
    local open = {}

    for item, quantity in pairs(items) do
        local transferred = transferItem(from, to, item, quantity, options)

        if transferred > 0 then
            transferredTotal[item] = transferred

            if transferred < quantity then
                open[item] = quantity - transferred
            end
        elseif quantity > 0 then
            open[item] = quantity
        end
    end

    return Utils.isEmpty(open), transferredTotal, open
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@param options? TransferOptions
---@return boolean transferredAll, ItemStock transferred, ItemStock open
function InventoryApi.transfer(from, to, stock, options)
    if isBufferHandle(to) then
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, stock)
    end

    return transferStock(from, to, stock, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.restock(from, to, options)
    local fromInventories, toInventories, options = getTransferArguments(from, to, options)
    local fromStock = InventoryApi.getStock(fromInventories, options.fromTag)
    local openStock = InventoryApi.getOpenStock(toInventories, options.toTag)

    ---@type ItemStock
    local filteredOpenStock = {}

    for item in pairs(fromStock) do
        filteredOpenStock[item] = openStock[item]
    end

    return transferStock(fromInventories, toInventories, filteredOpenStock, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.empty(from, to, options)
    local fromInventories, toInventories, options = getTransferArguments(from, to, options)

    if isBufferHandle(to) then
        local fromStock = InventoryApi.getStock(fromInventories, options.fromTag)
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, fromStock)
    end

    local fromStock = InventoryApi.getStock(fromInventories, options.fromTag)

    toInventories = Utils.filter(toInventories, function(to)
        if not InventoryCollection.isMounted(to) then
            return false
        end

        local inventory = InventoryCollection.get(to)

        for item in pairs(fromStock) do
            if Inventory.canTakeItem(inventory, item, options.toTag) then
                return true
            end
        end

        return false
    end)

    return transferStock(fromInventories, toInventories, fromStock, options)
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.fulfill(from, to, stock, options)
    if isBufferHandle(to) then
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, stock)
    end

    local fromInventories, toInventories, options = getTransferArguments(from, to, options)
    -- we're locking the toInventories to correctly read the open stock
    local lockSuccess, unlock, lockId = InventoryLocks.lock(toInventories, options.lockId)

    if not lockSuccess then
        -- [todo] ❌ it is kinda bad that we return false: we can't easily distinguish between "did chest disconnect" and "there were not enough items"
        return false, {}, {}
    end

    options.lockId = lockId

    local open = ItemStock.subtract(stock, InventoryApi.getStock(toInventories, options.toTag))
    local transferSuccess, transferred, open = transferStock(fromInventories, toInventories, open, options)
    unlock()

    return transferSuccess, transferred, open
end

---@param from InventoryHandle
---@param to InventoryHandle
---@param stock ItemStock
---@param options? TransferOptions
---@return boolean success, ItemStock transferred, ItemStock open
function InventoryApi.keep(from, to, stock, options)
    local fromInventories, toInventories, options = getTransferArguments(from, to, options)
    local lockSuccess, unlock, lockId = InventoryLocks.lock(fromInventories, options.lockId)

    if not lockSuccess then
        -- [todo] ❌ it is kinda bad that we return false: we can't easily distinguish between "did chest disconnect" and "there were not enough items"
        return false, {}, {}
    end

    options.lockId = lockId
    local fromStock = InventoryApi.getStock(fromInventories, options.fromTag)
    local open = ItemStock.subtract(fromStock, stock)

    if isBufferHandle(to) then
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, open)
    end

    local transferSuccess, transferred, open = transferStock(fromInventories, toInventories, open, options)
    unlock()

    return transferSuccess, transferred, open
end

---@type table<string, true>
local bufferLocks = {}

---@param bufferId integer
---@return fun() : nil
local function lock(bufferId)
    while bufferLocks[bufferId] do
        os.sleep(1)
    end

    bufferLocks[bufferId] = true

    return function()
        bufferLocks[bufferId] = nil
    end
end

---@return table<string, unknown>
local function getAllocatedInventories()
    ---@type table<string, unknown>
    local allocatedInventories = {}
    local allocatedBuffers = DatabaseApi.getAllocatedBuffers()

    for _, allocatedBuffer in pairs(allocatedBuffers) do
        for _, name in pairs(allocatedBuffer.inventories) do
            allocatedInventories[name] = true
        end
    end

    return allocatedInventories
end

---@param slotCount integer
local function getAllocationCandidates(slotCount)
    local buffers = InventoryApi.getByType("buffer")
    local alreadyAllocated = getAllocatedInventories()
    ---@type string[]
    local candidates = {}
    local openSlots = slotCount

    for _, buffer in pairs(buffers) do
        if not alreadyAllocated[buffer] then
            table.insert(candidates, buffer)
            openSlots = openSlots - InventoryApi.getSlotCount({buffer}, "buffer")

            if openSlots <= 0 then
                break
            end
        end
    end

    if openSlots > 0 then
        error(string.format("no more buffer available to fulfill %d slots (%d more required)", slotCount, openSlots))
    end

    return candidates
end

---@param bufferId integer
local function compact(bufferId)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)

    if #buffer.inventories == 1 then
        return
    end

    for i = #buffer.inventories, 1, -1 do
        local from = buffer.inventories[i]
        local to = {}

        for j = 1, i - 1 do
            table.insert(to, buffer.inventories[j])
        end

        if not InventoryApi.empty({from}, to, {toSequential = true, fromTag = "buffer", toTag = "buffer"}) then
            return
        end
    end
end

---@param bufferId integer
---@param targetSlotCount integer
local function resize(bufferId, targetSlotCount)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)
    local currentSlotCount = InventoryApi.getSlotCount(buffer.inventories, "buffer")

    if targetSlotCount < currentSlotCount then
        compact(bufferId)
        local openSlots = targetSlotCount
        ---@type string[]
        local resizedInventories = {}

        for i = 1, #buffer.inventories do
            local inventory = buffer.inventories[i]
            table.insert(resizedInventories, inventory)
            openSlots = openSlots - InventoryApi.getSlotCount({inventory}, "buffer")

            if openSlots <= 0 then
                break
            end
        end

        -- [todo] ❌ what if the "removed" inventories still contain items?
        buffer.inventories = resizedInventories
    else
        local newlyAllocated = getAllocationCandidates(targetSlotCount - currentSlotCount)

        for _, inventory in pairs(newlyAllocated) do
            table.insert(buffer.inventories, inventory)
        end
    end

    DatabaseApi.updateAllocatedBuffer(buffer)
end

---@param bufferId integer
---@return AllocatedBuffer
function InventoryApi.getBuffer(bufferId)
    return DatabaseApi.getAllocatedBuffer(bufferId)
end

---@param taskId integer
---@param slotCount? integer
---@return integer
function InventoryApi.allocateTaskBuffer(taskId, slotCount)
    slotCount = slotCount or 1
    local allocatedBuffer = DatabaseApi.findAllocatedBuffer(taskId)

    if allocatedBuffer then
        -- [todo] ❌ check if slotCount can still be fulfilled
        return allocatedBuffer.id
    end

    local newlyAllocated = getAllocationCandidates(slotCount)
    allocatedBuffer = DatabaseApi.createAllocatedBuffer(newlyAllocated, taskId)

    return allocatedBuffer.id
end

---@param bufferId integer
---@param targetSlotCount integer
function InventoryApi.resize(bufferId, targetSlotCount)
    local unlock = lock(bufferId)
    resize(bufferId, targetSlotCount)
    unlock()
end

---@param bufferId integer
---@param additionalStock ItemStock
function InventoryApi.resizeBufferByStock(bufferId, additionalStock)
    local unlock = lock(bufferId)
    local bufferStock = InventoryApi.getBufferStock(bufferId)
    local totalStock = ItemStock.merge({bufferStock, additionalStock})
    local requiredSlots = ItemApi.getRequiredSlotCount(totalStock)
    resize(bufferId, requiredSlots)
    unlock()
end

---@param bufferId integer
function InventoryApi.freeBuffer(bufferId)
    DatabaseApi.deleteAllocatedBuffer(bufferId)
end

---@param bufferId integer
---@return string[]
function InventoryApi.resolveBuffer(bufferId)
    return DatabaseApi.getAllocatedBuffer(bufferId).inventories
end

---@param bufferId integer
---@return ItemStock
function InventoryApi.getBufferStock(bufferId)
    local buffer = DatabaseApi.getAllocatedBuffer(bufferId)

    return InventoryApi.getStock(buffer.inventories, "buffer")
end

-- [todo] ❌ should throw if called twice
---@param bufferId integer
---@param to? InventoryHandle
function InventoryApi.flushAndFreeBuffer(bufferId, to)
    ---@type TransferOptions
    local options = {fromSequential = true, fromTag = "buffer"}
    ---@type string[]
    local toInventories = {}

    if not to then
        toInventories = InventoryApi.getByType("storage")
        options.toTag = "input"
    else
        toInventories, options = getToHandleTransferArguments(to, options)
    end

    local buffer = InventoryApi.getBuffer(bufferId)

    if to and isBufferHandle(to) then
        -- [todo] ❌ duplicated from InventoryApi.empty()
        local fromStock = InventoryApi.getStock(buffer.inventories, "buffer")
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, fromStock)
    end

    while not InventoryApi.empty(buffer.inventories, toInventories, options) do
        os.sleep(7)
    end

    InventoryApi.freeBuffer(bufferId)
end

local function onPeripheralEventMountInventory()
    while true do
        EventLoop.pull("peripheral", function(_, name)
            pcall(function(...)
                if InventoryReader.isInventoryType(name) then
                    InventoryCollection.mount({name})
                end
            end)
        end)
    end
end

---@param flag boolean
function InventoryApi.useCache(flag)
    InventoryCollection.useCache = flag
end

function InventoryApi.discover()
    print("[inventory] mounting connected inventories...")
    ---@type string[]
    local names = peripheral.getNames()

    local mountFns = Utils.map(names, function(name)
        return function()
            pcall(function(...)
                if InventoryReader.isInventoryType(name) then
                    InventoryCollection.mount({name})
                end
            end)
        end
    end)

    local chunkSize = 64
    local chunkedMountFns = Utils.chunk(mountFns, chunkSize)
    local x, y = Utils.printProgress(0, #chunkedMountFns)

    for i, chunk in pairs(chunkedMountFns) do
        EventLoop.run(table.unpack(chunk))
        x, y = Utils.printProgress(i, #chunkedMountFns, x, y)
    end
end

--- Runs the process of automatically mounting/unmounting any attached inventories until stopped.
--- Call "Inventory.stop()" inside another coroutine to stop.
function InventoryApi.start()
    EventLoop.runUntil("inventory:stop", function()
        onPeripheralEventMountInventory()
    end, function()
        while true do
            EventLoop.pull("peripheral_detach", function(_, name)
                if InventoryCollection.isMounted(name) then
                    print("[unmount]", name)
                    InventoryCollection.unmount({name})
                end
            end)
        end
    end)
end

function InventoryApi.stop()
    InventoryCollection.clear()
    InventoryLocks.clear()
    EventLoop.queue("inventory:stop")
end

return InventoryApi
