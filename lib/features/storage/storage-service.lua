local InventoryApi = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local TaskBufferService = require "lib.common.task-buffer-service"

---@class StorageService : Service
local StorageService = {name = "storage"}

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

-- [todo] all buffer related methods have been copied to TaskBufferService
---@param task Task
---@param slotCount? integer
---@return integer
function StorageService.allocateTaskBuffer(task, slotCount)
    return TaskBufferService.allocateTaskBuffer(task.id, slotCount)
end

---@param bufferId integer
function StorageService.freeBuffer(bufferId)
    TaskBufferService.freeBuffer(bufferId)
end

---@param bufferId integer
function StorageService.flushBuffer(bufferId)
    TaskBufferService.flushBuffer(bufferId)
end

---@param bufferId integer
---@param fromType? InventoryType
---@param fromTag? InventorySlotTag
---@param itemStock ItemStock
function StorageService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
    TaskBufferService.transferStockToBuffer(bufferId, itemStock, fromType, fromTag)
end

---@param bufferId integer
---@param from string
---@param fromTag InventorySlotTag
function StorageService.transferInventoryStockToBuffer(bufferId, from, fromTag)
    TaskBufferService.transferInventoryStockToBuffer(bufferId, from, fromTag)
end

---@param bufferId integer
---@return string[]
function StorageService.getBufferNames(bufferId)
    return TaskBufferService.getBufferNames(bufferId)
end

---@param bufferId integer
---@return ItemStock
function StorageService.getBufferStock(bufferId)
    return TaskBufferService.getBufferStock(bufferId)
end

---@param bufferId integer
---@param to string[]
---@param toTag InventorySlotTag
---@param stock? ItemStock
---@return ItemStock, ItemStock open
function StorageService.transferBufferStock(bufferId, to, toTag, stock)
    return TaskBufferService.transferBufferStock(bufferId, to, toTag, stock)
end

return StorageService
