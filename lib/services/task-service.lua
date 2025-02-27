local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local DatabaseService = require "lib.services.database-service"

---@class TaskService : Service
local TaskService = {name = "task", host = ""}

---@param issuedBy string
---@param type TaskType
---@param partOfTaskId? integer
---@param label? string
---@return Task
local function constructTask(issuedBy, type, partOfTaskId, label)
    ---@type Task
    local task = {id = 0, issuedBy = issuedBy, status = "issued", type = type, partOfTaskId = partOfTaskId, label = label}

    return task
end

---@param task Task
---@return Task
local function awaitTaskCompletion(task)
    while task.status ~= "finished" and task.status ~= "failed" do
        os.sleep(1)
        task = Rpc.nearest(DatabaseService).getTask(task.id)
    end

    return task
end

---@param id integer
---@return Task
function TaskService.getTask(id)
    return Rpc.nearest(DatabaseService).getTask(id)
end

---@param id integer
function TaskService.deleteTask(id)
    Rpc.nearest(DatabaseService).deleteTask(id)
end

---@param taskType TaskType
---@param partOfTaskId integer
---@param label string
---@return Task?
function TaskService.findTask(taskType, partOfTaskId, label)
    local databaseService = Rpc.nearest(DatabaseService)

    return Utils.find(databaseService.getTasks(), function(task)
        return task.type == taskType and task.partOfTaskId == partOfTaskId and task.label == label
    end)
end

---@param task Task
function TaskService.updateTask(task)
    Rpc.nearest(DatabaseService).updateTask(task)
end

---@param id integer
function TaskService.finishTask(id)
    local databaseService = Rpc.nearest(DatabaseService)
    databaseService.completeTask(id, "finished")
end

---@param id integer
function TaskService.failTask(id)
    local databaseService = Rpc.nearest(DatabaseService)
    databaseService.completeTask(id, "failed")
end

---@param acceptedBy string
---@param taskType TaskType
---@return Task
function TaskService.acceptTask(acceptedBy, taskType)
    local databaseService = Rpc.nearest(DatabaseService)
    local acceptedTask = databaseService.getAcceptedTask(acceptedBy, taskType)

    if acceptedTask then
        print(string.format("[found] %s #%d", taskType, acceptedTask.id))
        return acceptedTask
    end

    local task = databaseService.getIssuedTask(taskType)

    if not task then
        print(string.format("[wait] for %s...", taskType))
    end

    while not task do
        os.sleep(1)
        task = databaseService.getIssuedTask(taskType)

        if not task then
            task = databaseService.getAcceptedTask(acceptedBy, taskType)
        end
    end

    print(string.format("[found] %s #%d", taskType, task.id))

    if task.status == "issued" then
        task.acceptedBy = acceptedBy
        task.status = "accepted"
        databaseService.updateTask(task)
    end

    return task
end

---@param issuedBy string
---@param duration integer
---@return DanceTask
function TaskService.dance(issuedBy, duration)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = constructTask(issuedBy, "dance") --[[@as DanceTask]]
    task.duration = duration
    task = databaseService.createTask(task) --[[@as DanceTask]]

    return awaitTaskCompletion(task) --[[@as DanceTask]]
end

---[todo] I feel like it should be "WithdrawItems" instead of "TransferItems"?
---@class TransferItemsTaskOptions
---@field issuedBy string
---@field toBufferId? integer
---@field to? string[]
---@field toTag? InventorySlotTag
---@field items ItemStock
---@field partOfTaskId? integer
---@field label? string
---@param options TransferItemsTaskOptions
---@return TransferItemsTask
function TaskService.transferItems(options)
    -- [todo] what if properties like "to", "toTag", "targetStock" no longer match existing one?
    -- -> GatherItemsViaPlayerWorker actually relies on it being allowed to be different. wrote a todo note there.
    local task = TaskService.findTask("transfer-items", options.partOfTaskId, options.label) --[[@as TransferItemsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "transfer-items", options.partOfTaskId, options.label) --[[@as TransferItemsTask]]
        task.toBufferId = options.toBufferId
        task.to = options.to
        task.toTag = options.toTag
        task.items = options.items
        task.transferred = {}
        task.transferredAll = false
        task = databaseService.createTask(task) --[[@as TransferItemsTask]]
    end

    return awaitTaskCompletion(task) --[[@as TransferItemsTask]]
end

---@class CraftItemsTaskOptions
---@field issuedBy string
---@field partOfTaskId? integer
---@field label? string
---@field item string
---@field quantity integer
---@param options CraftItemsTaskOptions
---@return CraftItemsTask
function TaskService.craftItems(options)
    local task = TaskService.findTask("craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask]]
        task.item = options.item
        task.quantity = options.quantity
        task = databaseService.createTask(task) --[[@as CraftItemsTask]]
    end

    return awaitTaskCompletion(task) --[[@as CraftItemsTask]]
end

---@class AllocateIngredientsTaskOptions
---@field issuedBy string
---@field item string
---@field quantity integer
---@field partOfTaskId integer
---@field label string
---@param options AllocateIngredientsTaskOptions
---@return AllocateIngredientsTask
function TaskService.allocateIngredients(options)
    local task = TaskService.findTask("allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask]]
        task.items = {[options.item] = options.quantity}
        task = databaseService.createTask(task) --[[@as AllocateIngredientsTask]]
    end

    return awaitTaskCompletion(task) --[[@as AllocateIngredientsTask]]
end

---@class CraftFromIngredientsTaskOptions
---@field issuedBy string
---@field partOfTaskId integer
---@field label string
---@field craftingDetails CraftingDetails
---@field bufferId integer
---@param options CraftFromIngredientsTaskOptions
---@return CraftFromIngredientsTask
function TaskService.craftFromIngredients(options)
    local task = TaskService.findTask("craft-from-ingredients", options.partOfTaskId, options.label) --[[@as CraftFromIngredientsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "craft-from-ingredients", options.partOfTaskId, options.label) --[[@as CraftFromIngredientsTask]]
        task.craftingDetails = options.craftingDetails
        task.bufferId = options.bufferId
        task = databaseService.createTask(task) --[[@as CraftFromIngredientsTask]]
    end

    return awaitTaskCompletion(task) --[[@as CraftFromIngredientsTask]]
end

---@class GatherItemsTaskOptions
---@field issuedBy string
---@field items ItemStock
---@field to string[]
---@field toTag InventorySlotTag
---@field partOfTaskId? integer
---@field label? string
---@param options GatherItemsTaskOptions
---@return GatherItemsTask
function TaskService.gatherItems(options)
    -- [todo] what if properties like "items" no longer match existing one?
    local task = TaskService.findTask("gather-items", options.partOfTaskId, options.label) --[[@as GatherItemsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "gather-items", options.partOfTaskId, options.label) --[[@as GatherItemsTask]]
        task.items = options.items
        task.to = options.to
        task.toTag = options.toTag
        task = databaseService.createTask(task) --[[@as GatherItemsTask]]
    end

    return awaitTaskCompletion(task) --[[@as GatherItemsTask]]
end

---@class GatherItemsViaPlayerTaskOptions
---@field issuedBy string
---@field items ItemStock
---@field to string[]
---@field toTag InventorySlotTag
---@field partOfTaskId? integer
---@field label? string
---@param options GatherItemsViaPlayerTaskOptions
---@return GatherItemsViaPlayerTask
function TaskService.gatherItemsViaPlayer(options)
    -- [todo] what if properties like "items" no longer match existing one?
    local task = TaskService.findTask("gather-items-via-player", options.partOfTaskId, options.label) --[[@as GatherItemsViaPlayerTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "gather-items-via-player", options.partOfTaskId, options.label) --[[@as GatherItemsViaPlayerTask]]
        task.items = options.items
        task.open = options.items
        task.to = options.to
        task.toTag = options.toTag
        task = databaseService.createTask(task) --[[@as GatherItemsViaPlayerTask]]
    end

    return awaitTaskCompletion(task) --[[@as GatherItemsViaPlayerTask]]
end

return TaskService
