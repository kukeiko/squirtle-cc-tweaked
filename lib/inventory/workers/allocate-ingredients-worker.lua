local Rpc = require "lib.tools.rpc"
local TaskWorker = require "lib.system.task-worker"
local ItemStock = require "lib.inventory.item-stock"
local CraftingApi = require "lib.inventory.crafting-api"
local DatabaseService = require "lib.database.database-service"
local StorageService = require "lib.inventory.storage-service"

---@class AllocateIngredientsTaskWorker : TaskWorker
local AllocateIngredientsTaskWorker = {}
setmetatable(AllocateIngredientsTaskWorker, {__index = TaskWorker})

---@param task AllocateIngredientsTask
---@param taskService TaskService | RpcClient
---@return AllocateIngredientsTaskWorker
function AllocateIngredientsTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as AllocateIngredientsTaskWorker]]
    setmetatable(instance, {__index = AllocateIngredientsTaskWorker})

    return instance
end

---@return TaskType
function AllocateIngredientsTaskWorker.getTaskType()
    return "allocate-ingredients"
end

---@return AllocateIngredientsTask
function AllocateIngredientsTaskWorker:getTask()
    return self.task --[[@as AllocateIngredientsTask]]
end

function AllocateIngredientsTaskWorker:work()
    local task = self:getTask()
    local databaseService = Rpc.nearest(DatabaseService)
    local storageService = Rpc.nearest(StorageService)
    local recipes = databaseService.getCraftingRecipes()

    if not task.bufferId then
        -- [todo] ❌ buffer leak if turtle crashes before updateTask()
        task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
        self:updateTask()
    end

    while true do
        local bufferStock = storageService.getBufferStock(task.bufferId)
        local storageStock = storageService.getStock()
        local availableStock = ItemStock.merge({bufferStock, storageStock})
        local craftingDetails = CraftingApi.getCraftingDetails(task.items, availableStock, recipes)
        local targetStock = ItemStock.merge({craftingDetails.available, craftingDetails.unavailable})
        task.missing = craftingDetails.unavailable
        self:updateTask()

        if storageService.fulfill(storageService.getByType("storage"), task.bufferId, targetStock) then
            task.craftingDetails = craftingDetails
            task.missing = {}
            self:updateTask()
            break
        else
            os.sleep(5)
        end
    end

    -- no need to free/flush the buffer as it will be reused by craft-items
end

function AllocateIngredientsTaskWorker:cleanup()
    -- [todo] ❌ figure out if cleanup is needed
end

return AllocateIngredientsTaskWorker
