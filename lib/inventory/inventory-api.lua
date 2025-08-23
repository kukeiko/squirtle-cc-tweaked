local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.inventory.item-stock"
local Inventory = require "lib.inventory.inventory"
local DatabaseApi = require "lib.database.database-api"
local ItemApi = require "lib.inventory.item-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local InventoryReader = require "lib.inventory.inventory-reader"
local InventoryCollection = require "lib.inventory.inventory-collection"
local InventoryLocks = require "lib.inventory.inventory-locks"
local transferStock = require "lib.inventory.transfer-stock"
local transferItem = require "lib.inventory.transfer-item"
local getTransferArguments = require "lib.inventory.get-transfer-arguments"

---@class InventoryApi
local InventoryApi = {}
local defaultTransferRate = 1
local transferRate = defaultTransferRate

if turtle then
    transferRate = 8
end

---@type {item:string, transfer: integer}[]
local powerItems = {
    {item = ItemApi.coalBlock, transfer = 2},
    {item = ItemApi.copperBlock, transfer = 3},
    {item = ItemApi.ironBlock, transfer = 4},
    {item = ItemApi.redstoneBlock, transfer = 5},
    {item = ItemApi.goldBlock, transfer = 6},
    {item = ItemApi.diamondBlock, transfer = 7},
    {item = ItemApi.netheriteIngot, transfer = 8},
    {item = ItemApi.netheriteBlock, transfer = 16}
}

---@param type InventoryType
function InventoryApi.refresh(type)
    local inventories = InventoryApi.getByType(type)
    InventoryCollection.refresh(inventories)
end

---@param inventories InventoryHandle
function InventoryApi.refreshInventories(inventories)
    InventoryCollection.refresh(InventoryCollection.resolveHandle(inventories))
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

---@param from InventoryHandle
---@param to InventoryHandle
---@param item string
---@param quantity? integer
---@param options? TransferOptions
---@return integer transferredTotal
function InventoryApi.transferItem(from, to, item, quantity, options)
    options = options or {}
    options.rate = options.rate or transferRate
    return transferItem(from, to, item, quantity, options)
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

    options = options or {}
    options.rate = options.rate or transferRate

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
    options.rate = options.rate or transferRate

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
    options.rate = options.rate or transferRate

    if isBufferHandle(to) then
        local fromStock = InventoryApi.getStock(fromInventories, options.fromTag)
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, fromStock)
        toInventories = InventoryCollection.resolveBuffer(bufferId)
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
    options.rate = options.rate or transferRate

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
    options.rate = options.rate or transferRate

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
        toInventories = InventoryCollection.resolveBuffer(bufferId)
    end

    local transferSuccess, transferred, open = transferStock(fromInventories, toInventories, open, options)
    unlock()

    return transferSuccess, transferred, open
end

---@type table<string, true>
local bufferLocks = {}

---@param bufferId integer
---@return fun() : nil
local function lockBuffer(bufferId)
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
        print(string.format("[resize] buffer #%d from %d to %d slots", bufferId, currentSlotCount, targetSlotCount))
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
    elseif targetSlotCount > currentSlotCount then
        print(string.format("[resize] buffer #%d from %d to %d slots", bufferId, currentSlotCount, targetSlotCount))
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

-- [todo] ❌ would like to move some core buffer logic out of the InventoryApi, but it uses InventoryApi.empty(),
-- so I'll need some time to rework it. Probably should tackle it when I'm implementing the ability to await
-- buffers (i.e. if there are not enough buffers => don't throw, just wait until there are enough)
---@param bufferId integer
---@param additionalStock ItemStock
function InventoryApi.resizeBufferByStock(bufferId, additionalStock)
    local unlock = lockBuffer(bufferId)
    local bufferStock = InventoryCollection.getBufferStock(bufferId)
    local totalStock = ItemStock.merge({bufferStock, additionalStock})
    local requiredSlots = ItemApi.getRequiredSlotCount(totalStock)
    resize(bufferId, requiredSlots)
    unlock()
end

---@param bufferId integer
---@return ItemStock
function InventoryApi.getBufferStock(bufferId)
    return InventoryCollection.getBufferStock(bufferId)
end

-- [todo] ❌ should throw if called twice
---@param bufferId integer
---@param to? InventoryHandle
function InventoryApi.flushAndFreeBuffer(bufferId, to)
    to = to or InventoryApi.getByType("storage")
    local _, toInventories, options = getTransferArguments(bufferId, to)
    local buffer = InventoryApi.getBuffer(bufferId)

    if to and isBufferHandle(to) then
        -- [todo] ❌ duplicated from InventoryApi.empty()
        local fromStock = InventoryApi.getStock(buffer.inventories, "buffer")
        local bufferId = to --[[@as integer]]
        InventoryApi.resizeBufferByStock(bufferId, fromStock)
        toInventories = InventoryCollection.resolveBuffer(bufferId)
    end

    while not InventoryApi.empty(buffer.inventories, toInventories, options) do
        os.sleep(7)
    end

    InventoryCollection.freeBuffer(bufferId)
end

---@param inventory InventoryHandle
function InventoryApi.mount(inventory)
    InventoryCollection.mount(inventory)
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

---@param chest string
---@return integer
local function checkPower(chest)
    local power = defaultTransferRate

    if not peripheral.isPresent(chest) or peripheral.getType(chest) ~= "minecraft:chest" then
        return power
    end

    local stock = InventoryPeripheral.getStock(chest)

    for _, powerItem in ipairs(powerItems) do
        if stock[powerItem.item] then
            power = powerItem.transfer
        end
    end

    if stock[ItemApi.beacon] then
        power = power * 2
    end

    return power
end

--- Runs the process of automatically mounting/unmounting any attached inventories until stopped.
--- Call "Inventory.stop()" inside another coroutine to stop.
---@param powerChest? string
function InventoryApi.start(powerChest)
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
    end, function()
        if not powerChest then
            return
        end

        while true do
            local power = checkPower(powerChest)

            if transferRate ~= power then
                transferRate = power
                print(string.format("[inventory] transfer rate set to %d", transferRate))
            end

            os.sleep(10)
        end
    end)
end

function InventoryApi.stop()
    InventoryCollection.clear()
    InventoryLocks.clear()
    EventLoop.queue("inventory:stop")
end

return InventoryApi
