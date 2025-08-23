local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local TaskWorker = require "lib.system.task-worker"
local ItemStock = require "lib.inventory.item-stock"
local StorageService = require "lib.inventory.storage-service"

---@class ProvideItemsTaskWorker : TaskWorker
local ProvideItemsTaskWorker = {}
setmetatable(ProvideItemsTaskWorker, {__index = TaskWorker})

---@param task ProvideItemsTask
---@param taskService TaskService | RpcClient
---@return ProvideItemsTaskWorker
function ProvideItemsTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as ProvideItemsTaskWorker]]
    setmetatable(instance, {__index = ProvideItemsTaskWorker})

    return instance
end

---@return TaskType
function ProvideItemsTaskWorker.getTaskType()
    return "provide-items"
end

---@return ProvideItemsTask
function ProvideItemsTaskWorker:getTask()
    return self.task --[[@as ProvideItemsTask]]
end

function ProvideItemsTaskWorker:work()
    local storageService = Rpc.nearest(StorageService)
    local task = self:getTask()

    if not task.bufferId then
        -- [todo] ❌ buffer leak if turtle crashes before updateTask()
        task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
        self:updateTask()
    end

    if not task.transferredInitial then
        local from = storageService.getByType("storage")
        local _, transferred = storageService.fulfill(from, task.bufferId, task.items)
        task.transferredInitial = true
        task.transferred = transferred
        self:updateTask()
    end

    if task.craftMissing then
        -- [todo] ❌ issues craftItems() task even if nothing needs to be crafted,
        -- meaning that just providing items (without crafting) doesn't work if no crafter is running
        local bufferStock = storageService.getBufferStock(task.bufferId)
        local open = ItemStock.subtract(task.items, bufferStock)

        if not Utils.isEmpty(open) then
            local craftItemsTask = self:craftItems(open, task.bufferId)
            task.crafted = craftItemsTask.crafted
            self:updateTask()
        end
    end

    -- [todo] ❌ support "task.to" being nil, in which case another task will take over the buffer
    storageService.flushAndFreeBuffer(task.bufferId, task.to)
end

function ProvideItemsTaskWorker:cleanup()
    local storageService = Rpc.nearest(StorageService)
    local task = self:getTask()

    if task.bufferId then
        print(string.format("[cleanup] flush & free buffer %d...", task.bufferId))
        storageService.flushAndFreeBuffer(task.bufferId, task.to)
    end
end

return ProvideItemsTaskWorker
