local Utils = require "lib.common.utils"
local ItemStock = require "lib.common.models.item-stock"
local Rpc = require "lib.common.rpc"
local StorageService = require "lib.features.storage.storage-service"
local TaskService = require "lib.common.task-service"

---@param task TransferItemsTask
---@param storageService StorageService|RpcClient
---@return ItemStock
local function fillBuffer(task, storageService)
    local bufferStock = storageService.getBufferStock(task.bufferId)
    local openStock = ItemStock.subtract(task.items, bufferStock)

    if not Utils.isEmpty(openStock) then
        -- print("transfer stock to buffer...")
        storageService.transferStockToBuffer(task.bufferId, openStock)
    end

    return storageService.getBufferStock(task.bufferId)
end

---@param task TransferItemsTask
---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function updateTransferred(task, storageService, taskService)
    local bufferStock = storageService.getBufferStock(task.bufferId)
    local transferred = ItemStock.subtract(task.found, bufferStock)
    task.transferred = transferred
    task.transferredAll = Utils.isEmpty(ItemStock.subtract(task.items, transferred))
    taskService.updateTask(task)
end

---@param task TransferItemsTask
---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function emptyBuffer(task, storageService, taskService)
    -- print("transfer stock from buffer to target...")
    ---@type ItemStock
    storageService.transferBufferStock(task.bufferId, task.to, task.toTag)
    updateTransferred(task, storageService, taskService)

    local bufferStock = storageService.getBufferStock(task.bufferId)

    if not Utils.isEmpty(bufferStock) then
        -- print("trying to empty out the buffer...")

        while not Utils.isEmpty(bufferStock) do
            os.sleep(1)
            storageService.transferBufferStock(task.bufferId, task.to, task.toTag)
            updateTransferred(task, storageService, taskService)
            bufferStock = storageService.getBufferStock(task.bufferId)
        end

        -- print("managed to empty out buffer!")
    end
end

-- [todo] if it crashes, any allocated buffers need to be cleaned out
return function()
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print("[wait] for new task...")
        local task = taskService.acceptTransferItemsTask(os.getComputerLabel())
        print("[found] new task!", task.id)
        -- [todo] hardcoded slotCount
        local bufferId = task.bufferId or storageService.allocateTaskBuffer(task)

        if not task.bufferId then
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        if not task.found then
            task.found = fillBuffer(task, storageService)
            taskService.updateTask(task)
        end

        emptyBuffer(task, storageService, taskService)
        print("[finish] task!", task.id)
        taskService.finishTask(task.id)
        storageService.freeBuffer(bufferId)
    end
end
