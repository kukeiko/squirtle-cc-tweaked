local Utils = require "lib.tools.utils"
local ItemStock = require "lib.models.item-stock"
local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.systems.task.task-service"
local TaskBufferService = require "lib.systems.task.task-buffer-service"
local StorageService = require "lib.systems.storage.storage-service"

---@param task TransferItemsTask
---@param taskBufferService TaskBufferService|RpcClient
---@return ItemStock
local function fillBuffer(task, taskBufferService)
    local bufferStock = taskBufferService.getBufferStock(task.bufferId)
    local openStock = ItemStock.subtract(task.items, bufferStock)

    if not Utils.isEmpty(openStock) then
        taskBufferService.transferStockToBuffer(task.bufferId, openStock)
    end

    return taskBufferService.getBufferStock(task.bufferId)
end

---@param task TransferItemsTask
---@param taskBufferService TaskBufferService|RpcClient
---@param taskService TaskService|RpcClient
local function updateTransferred(task, taskBufferService, taskService)
    local bufferStock = taskBufferService.getBufferStock(task.bufferId)
    local transferred = ItemStock.subtract(task.found, bufferStock)
    task.transferred = transferred
    task.transferredAll = Utils.isEmpty(ItemStock.subtract(task.items, transferred))
    taskService.updateTask(task)
end

---@param task TransferItemsTask
---@param taskBufferService TaskBufferService|RpcClient
---@param taskService TaskService|RpcClient
local function emptyBuffer(task, taskBufferService, taskService)
    local to, toTag = task.to, task.toTag

    if task.toBufferId then
        toTag = "buffer"
        taskBufferService.resizeByStock(task.toBufferId, task.items)
        to = taskBufferService.getBufferNames(task.toBufferId)
    elseif not to or not toTag then
        error("to and/or toTag not set")
    end

    -- print("transfer stock from buffer to target...")
    ---@type ItemStock
    taskBufferService.transferBufferStock(task.bufferId, to, toTag)
    updateTransferred(task, taskBufferService, taskService)

    local bufferStock = taskBufferService.getBufferStock(task.bufferId)

    if not Utils.isEmpty(bufferStock) then
        -- print("trying to empty out the buffer...")

        while not Utils.isEmpty(bufferStock) do
            os.sleep(1)
            taskBufferService.transferBufferStock(task.bufferId, to, toTag)
            updateTransferred(task, taskBufferService, taskService)
            bufferStock = taskBufferService.getBufferStock(task.bufferId)
        end

        -- print("managed to empty out buffer!")
    end
end

-- [todo] if it crashes, any allocated buffers need to be cleaned out
return function()
    local taskService = Rpc.nearest(TaskService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print(string.format("[awaiting] next %s...", "transfer-items"))
        local task = taskService.acceptTask(os.getComputerLabel(), "transfer-items") --[[@as TransferItemsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))
        local requiredSlotCount = storageService.getRequiredSlotCount(task.items)
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id, requiredSlotCount)

        if not task.bufferId then
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        if not task.found then
            task.found = fillBuffer(task, taskBufferService)
            taskService.updateTask(task)
        end

        emptyBuffer(task, taskBufferService, taskService)
        print(string.format("[finish] %s %d", task.type, task.id))
        taskService.finishTask(task.id)
        taskBufferService.freeBuffer(bufferId)
    end
end
