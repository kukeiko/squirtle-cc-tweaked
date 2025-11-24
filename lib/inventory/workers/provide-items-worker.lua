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

    repeat
        -- before we can allocate a task buffer, we need to have ItemDetails available for all items to get the maxCount,
        -- so we report what's missing and wait until it has been resolved by the player.
        task.missingDetails = storageService.filterIsMissingDetails(task.items)
        self:updateTask()
    until Utils.isEmpty(task.missingDetails) or os.sleep(7)

    if not task.bufferId then
        task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
        self:updateTask()
    end

    -- transfer wanted items into the buffer to prevent someone else taking them.
    -- we're using a flag to ensure idempotency and to keep this task simple as missing items will be crafted.
    if not task.transferredInitial then
        local from = storageService.getByType("storage")
        storageService.fulfill(from, task.bufferId, task.items)
        task.transferredInitial = true
        task.transferred = storageService.getBufferStock(task.bufferId)
        self:updateTask()
    end

    -- crafts the missing items if allowed and possible and transfers them directly into the buffer.
    if task.craftMissing then
        local bufferStock = storageService.getBufferStock(task.bufferId)
        local open = ItemStock.subtract(task.items, bufferStock)
        local craftingRecipes = storageService.getCraftingRecipes()
        local openCraftable = Utils.filterMap(open, function(_, item)
            return craftingRecipes[item] ~= nil
        end)

        if not Utils.isEmpty(openCraftable) then
            self:craftItems(openCraftable, task.bufferId)
            task.transferred = storageService.getBufferStock(task.bufferId)
            self:updateTask()
        end
    end

    local open = ItemStock.subtract(task.items, storageService.getBufferStock(task.bufferId))

    -- transfer missing items from the storage to the buffer until all are found
    if not Utils.isEmpty(open) then
        while true do
            local fulfilled = storageService.fulfill(storageService.getByType("storage"), task.bufferId, task.items)
            task.transferred = storageService.getBufferStock(task.bufferId)
            task.missing = ItemStock.subtract(task.items, task.transferred)
            self:updateTask()

            if fulfilled then
                break
            end

            os.sleep(5)
        end
    end

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
