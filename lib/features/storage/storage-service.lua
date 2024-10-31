local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local InventoryApi = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local DatabaseService = require "lib.common.database-service"

---@class StorageService : Service
local StorageService = {name = "storage"}

local function getDatabaseService()
    local databaseService = Rpc.tryNearest(DatabaseService)

    if not databaseService then
        error("could not connect to DatabaseService")
    end

    return databaseService
end

---@return table<string, unknown>
local function getAllocatedInventories()
    local databaseService = getDatabaseService()
    ---@type table<string, unknown>
    local allocatedInventories = {}
    local allocatedBuffers = databaseService.getAllocatedBuffers()

    for _, allocatedBuffer in pairs(allocatedBuffers) do
        for _, name in pairs(allocatedBuffer.inventories) do
            allocatedInventories[name] = true
        end
    end

    return allocatedInventories
end

---@param stashLabel string
function StorageService.getStashName(stashLabel)
    return InventoryApi.getByTypeAndLabel("stash", stashLabel)
end

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock, ItemStock open
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = StorageService.getStashName(stashLabel)
    return InventoryApi.transferItems(InventoryApi.getAll(), "withdraw", {stash}, "input", itemStock)
end

---@param stashLabel string
---@param item string
---@param total integer
---@return integer
function StorageService.transferItemToStash(stashLabel, item, total)
    local transferred = StorageService.transferStockToStash(stashLabel, {[item] = total})

    return transferred[item] or 0
end

---@return ItemStock
function StorageService.getStock()
    local storages = InventoryApi.getByType("storage")
    return InventoryApi.getStock(storages, "withdraw")
end

function StorageService.getItemDisplayNames()
    return InventoryPeripheral.getItemDisplayNames()
end

---@param quest Quest
---@param slotCount? integer
---@return integer
function StorageService.allocateQuestBuffer(quest, slotCount)
    local databaseService = getDatabaseService()
    local allocatedBy = quest.acceptedBy

    if not allocatedBy then
        error(string.format("quest #%d has no 'acceptedBy' assigned", quest.id))
    end

    slotCount = slotCount or 26 -- minus one to account for buffer name tag
    local allocatedBuffer = databaseService.findAllocatedBuffer(allocatedBy, quest.id)

    if allocatedBuffer then
        -- [todo] check if slotCount can still be fulfilled
        return allocatedBuffer.id
    end

    local buffers = InventoryApi.getByType("buffer")
    local alreadyAllocated = getAllocatedInventories()
    ---@type string[]
    local newlyAllocated = {}
    local openSlots = slotCount

    for _, buffer in pairs(buffers) do
        if not alreadyAllocated[buffer] then
            table.insert(newlyAllocated, buffer)
            openSlots = openSlots - InventoryApi.getSlotCount({buffer}, "buffer")

            if openSlots <= 0 then
                break
            end
        end
    end

    if openSlots > 0 then
        error(string.format("no more buffer available to fulfill %d slots (%d more required)", slotCount, openSlots))
    end

    allocatedBuffer = databaseService.createAllocatedBuffer(allocatedBy, newlyAllocated, quest.id)

    return allocatedBuffer.id
end

---@param bufferId integer
function StorageService.freeBuffer(bufferId)
    local databaseService = getDatabaseService()
    databaseService.deleteAllocatedBuffer(bufferId)
end

---@param bufferId integer
function StorageService.flushBuffer(bufferId)
    local storages = InventoryApi.getByType("storage")

    while not Utils.isEmpty(StorageService.getBufferStock(bufferId)) do
        StorageService.transferBufferStock(bufferId, storages, "input")
        os.sleep(1)
    end
end

---@param bufferId integer
---@param fromType? InventoryType
---@param fromTag? InventorySlotTag
---@param itemStock ItemStock
function StorageService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local storages = InventoryApi.getByType(fromType or "storage")
    InventoryApi.transferItems(storages, fromTag or "withdraw", buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@param from string
---@param fromTag InventorySlotTag
function StorageService.transferInventoryStockToBuffer(bufferId, from, fromTag)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local itemStock = InventoryApi.getStock({from}, fromTag)
    InventoryApi.transferItems({from}, fromTag, buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@return string[]
function StorageService.getBufferNames(bufferId)
    local databaseService = getDatabaseService()
    return databaseService.getAllocatedBuffer(bufferId).inventories
end

---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)

    return InventoryApi.getStock(buffer.inventories, "buffer")
end

---@param bufferId integer
---@param to string[]
---@param toTag InventorySlotTag
---@param stock? ItemStock
---@return ItemStock, ItemStock open
function StorageService.transferBufferStock(bufferId, to, toTag, stock)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local bufferStock = stock or StorageService.getBufferStock(bufferId)
    return InventoryApi.transferItems(buffer.inventories, "buffer", to, toTag, bufferStock, {fromSequential = true})
end

return StorageService
