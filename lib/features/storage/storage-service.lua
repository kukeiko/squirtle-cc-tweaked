local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local ItemStock = require "lib.common.models.item-stock"
local InventoryApi = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local DatabaseService = require "lib.common.database-service"

---@class StorageService : Service
local StorageService = {name = "storage"}

local function getDatabaseService()
    local databaseService = Rpc.nearest(DatabaseService)

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
    local stash = InventoryApi.findInventoryByTypeAndLabel("stash", stashLabel)

    if not stash then
        error(string.format("stash %s doesn't exist", stashLabel))
    end

    return stash
end

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = StorageService.getStashName(stashLabel)
    return InventoryApi.distributeItems(InventoryApi.getInventories(), {stash}, itemStock, "withdraw", "input")
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
    return InventoryApi.getStockByTag("withdraw")
end

---@param inventory string
---@param tag InventorySlotTag
---@param refresh? boolean
---@return ItemStock
function StorageService.getInventoryStock(inventory, tag, refresh)
    return InventoryApi.getInventoryStockByTag(inventory, tag, refresh)
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

    local buffers = InventoryApi.getInventories("buffer")
    local alreadyAllocated = getAllocatedInventories()
    ---@type string[]
    local newlyAllocated = {}
    local openSlots = slotCount

    for _, buffer in pairs(buffers) do
        if not alreadyAllocated[buffer] then
            table.insert(newlyAllocated, buffer)
            openSlots = openSlots - InventoryApi.getInventorySlotCount(buffer, "buffer")

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
    local storages = InventoryApi.getInventories("storage")

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
    InventoryApi.refresh(buffer.inventories) -- [todo] for testing purposes
    local storages = InventoryApi.getInventories(fromType or "storage")
    InventoryApi.transferItems(storages, fromTag or "withdraw", buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@param from string
---@param fromTag InventorySlotTag
function StorageService.transferInventoryStockToBuffer(bufferId, from, fromTag)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    InventoryApi.refresh(buffer.inventories) -- [todo] for testing purposes
    local itemStock = InventoryApi.getInventoryStockByTag(from, fromTag, true) -- [todo] for testing purposes / re-evaluate
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
    ---@type ItemStock
    local stock = {}

    for _, inventory in pairs(buffer.inventories) do
        stock = ItemStock.add(stock, InventoryApi.getInventoryStockByTag(inventory, "buffer"))
    end

    return stock
end

---@param bufferId integer
---@param to string[]
---@param toTag InventorySlotTag
---@param stock? ItemStock
---@return ItemStock
function StorageService.transferBufferStock(bufferId, to, toTag, stock)
    local databaseService = getDatabaseService()
    local buffer = databaseService.getAllocatedBuffer(bufferId)
    local bufferStock = stock or StorageService.getBufferStock(bufferId)
    return InventoryApi.transferItems(buffer.inventories, "buffer", to, toTag, bufferStock, {fromSequential = true})
end

return StorageService
