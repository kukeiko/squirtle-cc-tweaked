local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"
local TaskBufferService = require "lib.common.task-buffer-service"

---@class TaskService : Service
local TaskService = {name = "task", host = ""}

---@param issuedBy string
---@param type TaskType
---@return Task
local function constructTask(issuedBy, type)
    ---@type Task
    local task = {id = 0, issuedBy = issuedBy, status = "issued", type = type, prerequisiteIds = {}, prerequisites = {}}

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

---@param acceptedBy string
---@param taskType TaskType
---@return Task
local function acceptTask(acceptedBy, taskType)
    local databaseService = Rpc.nearest(DatabaseService)
    local acceptedTask = databaseService.getAcceptedTask(acceptedBy, taskType)

    if acceptedTask then
        print("[found] accepted immediately", acceptedTask.id)
        return acceptedTask
    end

    local task = databaseService.getIssuedPreparedTask(taskType)

    if not task then
        print(string.format("[wait] for issued/accepted %s task...", taskType))
    end

    while not task do
        os.sleep(1)
        task = databaseService.getIssuedPreparedTask(taskType)

        if not task then
            task = databaseService.getAcceptedTask(acceptedBy, taskType)
        end
    end

    print("[found] issued/accepted task!", task.id, task.status)

    if task.status == "issued" then
        task.acceptedBy = acceptedBy
        task.status = "accepted"
        databaseService.updateTask(task)
        print("[saved] as accepted")
    end

    return task
end

---@param id integer
---@return Task
function TaskService.getTask(id)
    return Rpc.nearest(DatabaseService).getTask(id)
end

---@param id integer
function TaskService.signOffTask(id)
    Rpc.nearest(DatabaseService).deleteTask(id)
end

---@param issuedBy string
---@param duration integer
---@return DanceTask
function TaskService.issueDanceTask(issuedBy, duration)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = constructTask(issuedBy, "dance") --[[@as DanceTask]]
    task.duration = duration
    task = databaseService.createTask(task) --[[@as DanceTask]]

    return task
end

---[todo] I feel like it should be "WithdrawItems" instead of "TransferItems"?
---@class TransferItemsTaskOptions
---@field issuedBy string
---@field to string[]
---@field toTag InventorySlotTag
---@field targetStock ItemStock
---@field partOfTaskId? integer
---@field label? string
---@param options TransferItemsTaskOptions
---@return TransferItemsTask
function TaskService.transferItems(options)
    ---@type TransferItemsTask?
    local task

    if options.partOfTaskId and options.label then
        -- [todo] what if properties like "to", "toTag", "targetStock" no longer match existing one?
        -- -> GatherItemsViaPlayerWorker actually relies on it being allowed to be different. wrote a todo note there.
        task = TaskService.findTransferItemTask(options.partOfTaskId, options.label)
    end

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "transfer-items") --[[@as TransferItemsTask]]
        task.to = options.to
        task.toTag = options.toTag
        task.items = options.targetStock
        task.transferred = {}
        task.transferredAll = false
        task.partOfTaskId = options.partOfTaskId
        task.label = options.label
        task = databaseService.createTask(task) --[[@as TransferItemsTask]]
    end

    return TaskService.awaitTransferItemsTaskCompletion(task)
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
    ---@type GatherItemsTask?
    local task

    if options.partOfTaskId and options.label then
        -- [todo] what if properties like "items" no longer match existing one?
        task = TaskService.findTask("gather-items", options.partOfTaskId, options.label) --[[@as GatherItemsTask?]]
    end

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "gather-items") --[[@as GatherItemsTask]]
        task.items = options.items
        task.to = options.to
        task.toTag = options.toTag
        task.partOfTaskId = options.partOfTaskId
        task.label = options.label
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
    ---@type GatherItemsViaPlayerTask?
    local task

    if options.partOfTaskId and options.label then
        -- [todo] what if properties like "items" no longer match existing one?
        task = TaskService.findTask("gather-items-via-player", options.partOfTaskId, options.label) --[[@as GatherItemsViaPlayerTask?]]
    end

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "gather-items-via-player") --[[@as GatherItemsViaPlayerTask]]
        task.items = options.items
        task.open = options.items
        task.to = options.to
        task.toTag = options.toTag
        task.partOfTaskId = options.partOfTaskId
        task.label = options.label
        task = databaseService.createTask(task) --[[@as GatherItemsViaPlayerTask]]
    end

    return awaitTaskCompletion(task) --[[@as GatherItemsViaPlayerTask]]
end

---@param issuedBy string
---@param item string
---@param quantity integer
---@return CraftItemsTask
function TaskService.issueCraftItemTask(issuedBy, item, quantity)
    local databaseService = Rpc.nearest(DatabaseService)
    local allocateIngredientsTask = constructTask(issuedBy, "allocate-ingredients") --[[@as AllocateIngredientsTask]]
    allocateIngredientsTask.items = {[item] = quantity}
    allocateIngredientsTask = databaseService.createTask(allocateIngredientsTask) --[[@as AllocateIngredientsTask]]

    -- [todo] might unload here, causing CraftItemsTask to never be created.
    -- proposal as a solution: just create AllocateIngredientsTask, and the worker, upon completion of that,
    -- will create the CraftItemsTask
    local task = constructTask(issuedBy, "craft-items") --[[@as CraftItemsTask]]
    task.item = item
    task.quantity = quantity
    task.allocateIngredientsTaskId = allocateIngredientsTask.id
    task.prerequisiteIds = {allocateIngredientsTask.id}
    task = databaseService.createTask(task) --[[@as CraftItemsTask]]

    return task
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

---@param partOfTaskId integer
---@param label string
---@return TransferItemsTask?
function TaskService.findTransferItemTask(partOfTaskId, label)
    local databaseService = Rpc.nearest(DatabaseService)

    return Utils.find(databaseService.getTasks(), function(task)
        return task.type == "transfer-items" and task.partOfTaskId == partOfTaskId and task.label == label
    end) --[[@as TransferItemsTask?]]
end

---@param acceptedBy string
---@return DanceTask
function TaskService.acceptDanceTask(acceptedBy)
    return acceptTask(acceptedBy, "dance") --[[@as DanceTask]]
end

---@param acceptedBy string
---@return TransferItemsTask
function TaskService.acceptTransferItemsTask(acceptedBy)
    return acceptTask(acceptedBy, "transfer-items") --[[@as TransferItemsTask]]
end

---@param acceptedBy string
---@return AllocateIngredientsTask
function TaskService.acceptAllocateIngredientsTask(acceptedBy)
    return acceptTask(acceptedBy, "allocate-ingredients") --[[@as AllocateIngredientsTask]]
end

---@param acceptedBy string
---@return GatherItemsTask
function TaskService.acceptGatherItemsTask(acceptedBy)
    return acceptTask(acceptedBy, "gather-items") --[[@as GatherItemsTask]]
end

---@param acceptedBy string
---@return GatherItemsViaPlayerTask
function TaskService.acceptGatherItemsViaPlayerTask(acceptedBy)
    return acceptTask(acceptedBy, "gather-items-via-player") --[[@as GatherItemsViaPlayerTask]]
end

---@param acceptedBy string
---@return CraftItemsTask
function TaskService.acceptCraftItemTask(acceptedBy)
    return acceptTask(acceptedBy, "craft-items") --[[@as CraftItemsTask]]
end

---@param task DanceTask
---@return DanceTask
function TaskService.awaitDanceTaskCompletion(task)
    return awaitTaskCompletion(task) --[[@as DanceTask]]
end

---@param task TransferItemsTask
---@return TransferItemsTask
function TaskService.awaitTransferItemsTaskCompletion(task)
    return awaitTaskCompletion(task) --[[@as TransferItemsTask]]
end

---@param task CraftItemsTask
---@return CraftItemsTask
function TaskService.awaitCraftItemTaskCompletion(task)
    return awaitTaskCompletion(task) --[[@as CraftItemsTask]]
end

---@param task Task
function TaskService.updateTask(task)
    Rpc.nearest(DatabaseService).updateTask(task)
end

---@param id integer
function TaskService.finishTask(id)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = databaseService.getTask(id)
    task.status = "finished"
    databaseService.updateTask(task)
end

---@param id integer
function TaskService.failTask(id)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = databaseService.getTask(id)
    task.status = "failed"
    databaseService.updateTask(task)
end

return TaskService
