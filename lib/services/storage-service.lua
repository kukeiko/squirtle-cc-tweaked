local ItemStock = require "common.models.item-stock"
local InventoryApi = require "inventory"
local InventoryPeripheral = require "inventory.inventory-peripheral"
local DatabaseService = require "common.database-service"

---@class StorageService : Service
local StorageService = {name = "storage"}

---@return table<string, unknown>
local function getAllocatedInventories()
    ---@type table<string, unknown>
    local allocatedInventories = {}
    local allocatedBuffers = DatabaseService.getAllocatedBuffers()

    for _, allocatedBuffer in pairs(allocatedBuffers) do
        for _, name in pairs(allocatedBuffer.inventories) do
            allocatedInventories[name] = true
        end
    end

    return allocatedInventories
end

---@param stashLabel string
---@param itemStock ItemStock
---@return ItemStock
function StorageService.transferStockToStash(stashLabel, itemStock)
    local stash = InventoryApi.findInventoryByTypeAndLabel("stash", stashLabel)

    if not stash then
        error(string.format("stash %s doesn't exist", stashLabel))
    end

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

function StorageService.getItemDisplayNames()
    return InventoryPeripheral.getItemDisplayNames()
end

---@param quest Quest
---@param slotCount? integer
---@return integer
function StorageService.allocateQuestBuffer(quest, slotCount)
    local allocatedBy = quest.acceptedBy

    if not allocatedBy then
        error(string.format("quest #%d has no 'acceptedBy' assigned", quest.id))
    end

    slotCount = slotCount or 26 -- minus one to account for buffer name tag
    local allocatedBuffer = DatabaseService.findAllocatedBuffer(allocatedBy, quest.id)

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

    allocatedBuffer = DatabaseService.createAllocatedBuffer(allocatedBy, newlyAllocated, quest.id)

    return allocatedBuffer.id
end

---@param bufferId integer
function StorageService.freeBuffer(bufferId)
    DatabaseService.deleteAllocatedBuffer(bufferId)
end

---@param bufferId integer
---@param itemStock ItemStock
function StorageService.transferStockToBuffer(bufferId, itemStock)
    local buffer = DatabaseService.getAllocatedBuffer(bufferId)
    InventoryApi.refresh(buffer.inventories) -- [todo] for testing purposes
    local storages = InventoryApi.getInventories("storage")
    InventoryApi.transferItems(storages, "withdraw", buffer.inventories, "buffer", itemStock, {toSequential = true})
end

---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    local buffer = DatabaseService.getAllocatedBuffer(bufferId)
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
---@return ItemStock
function StorageService.transferBufferStock(bufferId, to, toTag)
    local buffer = DatabaseService.getAllocatedBuffer(bufferId)
    local bufferStock = StorageService.getBufferStock(bufferId)
    return InventoryApi.transferItems(buffer.inventories, "buffer", to, toTag, bufferStock, {fromSequential = true})
end

return StorageService
