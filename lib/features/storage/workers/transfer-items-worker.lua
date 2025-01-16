local Utils = require "lib.common.utils"
local ItemStock = require "lib.common.models.item-stock"
local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"

---@param task TransferItemsTask
---@param taskBufferService TaskBufferService|RpcClient
---@return ItemStock
local function fillBuffer(task, taskBufferService)
    local bufferStock = taskBufferService.getBufferStock(task.bufferId)
    local openStock = ItemStock.subtract(task.items, bufferStock)

    if not Utils.isEmpty(openStock) then
        -- print("transfer stock to buffer...")
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
    -- print("transfer stock from buffer to target...")
    ---@type ItemStock
    taskBufferService.transferBufferStock(task.bufferId, task.to, task.toTag)
    updateTransferred(task, taskBufferService, taskService)

    local bufferStock = taskBufferService.getBufferStock(task.bufferId)

    if not Utils.isEmpty(bufferStock) then
        -- print("trying to empty out the buffer...")

        while not Utils.isEmpty(bufferStock) do
            os.sleep(1)
            taskBufferService.transferBufferStock(task.bufferId, task.to, task.toTag)
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

    while true do
        print("[wait] for new task...")
        local task = taskService.acceptTask(os.getComputerLabel(), "transfer-items") --[[@as TransferItemsTask]]
        print("[found] new task!", task.id)
        -- [todo] hardcoded slotCount
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id)

        if not task.bufferId then
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        if not task.found then
            task.found = fillBuffer(task, taskBufferService)
            taskService.updateTask(task)
        end

        emptyBuffer(task, taskBufferService, taskService)
        print("[finish] task!", task.id)
        taskService.finishTask(task.id)
        taskBufferService.freeBuffer(bufferId)
    end
end
