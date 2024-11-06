local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"

---@class TaskService : Service
local TaskService = {name = "task", host = ""}

---@param issuedBy string
---@param type TaskType
---@return Task
local function constructTask(issuedBy, type)
    ---@type Task
    local task = {id = 0, issuedBy = issuedBy, status = "issued", type = type}

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

    local task = databaseService.getIssuedTask(taskType)

    if not task then
        print("[wait] for issued/accepted task...")
    end

    while not task do
        os.sleep(1)
        task = databaseService.getIssuedTask(taskType)

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

---@param issuedBy string
---@param to string[]
---@param toTag InventorySlotTag
---@param targetStock ItemStock
---@param partOfTaskId? integer
---@param label? string
---@return TransferItemsTask
function TaskService.issueTransferItemsTask(issuedBy, to, toTag, targetStock, partOfTaskId, label)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = constructTask(issuedBy, "transfer-items") --[[@as TransferItemsTask]]
    task.to = to
    task.toTag = toTag
    task.items = targetStock
    task.transferred = {}
    task.transferredAll = false
    task.partOfTaskId = partOfTaskId
    task.label = label
    task = databaseService.createTask(task) --[[@as TransferItemsTask]]

    return task
end

---@param issuedBy string
---@param item string
---@param quantity integer
---@return CraftItemTask
function TaskService.issueCraftItemTask(issuedBy, item, quantity)
    local databaseService = Rpc.nearest(DatabaseService)
    local task = constructTask(issuedBy, "craft-item") --[[@as CraftItemTask]]
    task.item = item
    task.quantity = quantity
    task = databaseService.createTask(task) --[[@as CraftItemTask]]

    return task
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
---@return CraftItemTask
function TaskService.acceptCraftItemTask(acceptedBy)
    return acceptTask(acceptedBy, "craft-item") --[[@as CraftItemTask]]
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

---@param task CraftItemTask
---@return CraftItemTask
function TaskService.awaitCraftItemTaskCompletion(task)
    awaitTaskCompletion(task) --[[@as CraftItemTask]]
end

---@param task Task
function TaskService.updateTask(task)
    local databaseService = Rpc.nearest(DatabaseService)
    databaseService.updateTask(task)
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
