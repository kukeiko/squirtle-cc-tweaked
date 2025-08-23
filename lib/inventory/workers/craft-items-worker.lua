local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local TaskWorker = require "lib.system.task-worker"
local ItemStock = require "lib.inventory.item-stock"
local StorageService = require "lib.inventory.storage-service"

---@class CraftItemsTaskWorker : TaskWorker
local CraftItemsTaskWorker = {}
setmetatable(CraftItemsTaskWorker, {__index = TaskWorker})

---@param task CraftItemsTask
---@param taskService TaskService | RpcClient
---@return CraftItemsTaskWorker
function CraftItemsTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as CraftItemsTaskWorker]]
    setmetatable(instance, {__index = CraftItemsTaskWorker})

    return instance
end

---@return TaskType
function CraftItemsTaskWorker.getTaskType()
    return "craft-items"
end

---@return CraftItemsTask
function CraftItemsTaskWorker:getTask()
    return self.task --[[@as CraftItemsTask]]
end

function CraftItemsTaskWorker:work()
    local task = self:getTask()
    local storageService = Rpc.nearest(StorageService)
    local allocateIngredientsTask = self:allocateIngredients(task.items)
    local bufferId = allocateIngredientsTask.bufferId --[[@as integer]]
    local craftFromIngredientsTask = self:craftFromIngredients(allocateIngredientsTask.craftingDetails, bufferId)
    local craftedSpillover = ItemStock.subtract(storageService.getBufferStock(bufferId), task.items)

    if not Utils.isEmpty(craftedSpillover) then
        while not storageService.keep(bufferId, storageService.getByType("storage"), task.items) do
            os.sleep(5)
        end
    end

    task.crafted = craftFromIngredientsTask.crafted
    self:updateTask()
    storageService.flushAndFreeBuffer(bufferId, task.to)
end

function CraftItemsTaskWorker:cleanup()
    -- [todo] ❌ figure out if cleanup is needed
end

return CraftItemsTaskWorker
