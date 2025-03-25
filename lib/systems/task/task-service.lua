local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local DatabaseService = require "lib.systems.database.database-service"
local TaskRepository = require "lib.apis.database.task-repository"

---@class TaskService : Service
local TaskService = {name = "task", host = ""}

---@param issuedBy string
---@param type TaskType
---@param partOfTaskId? integer
---@param label? string
---@param autoDelete? boolean
---@return Task
local function constructTask(issuedBy, type, partOfTaskId, label, autoDelete)
    ---@type Task
    local task = {
        id = 0,
        issuedBy = issuedBy,
        status = "issued",
        type = type,
        partOfTaskId = partOfTaskId,
        label = label,
        autoDelete = autoDelete or false
    }

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

---@class ProvideItemsTaskOptions
---@field issuedBy string
---@field partOfTaskId? integer
---@field label? string
---@field await? boolean
---@field autoDelete? boolean
---@field items ItemStock
---@field to InventoryHandle
---@field craftMissing boolean
---@param options ProvideItemsTaskOptions
---@return ProvideItemsTask
function TaskService.provideItems(options)
    local task = TaskService.findTask("provide-items", options.partOfTaskId, options.label) --[[@as ProvideItemsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "provide-items", options.partOfTaskId, options.label, options.autoDelete) --[[@as ProvideItemsTask]]
        task.transferredInitial = false
        task.items = options.items
        task.to = options.to
        task.craftMissing = options.craftMissing
        task.transferred = {}
        task.crafted = {}
        task = databaseService.createTask(task) --[[@as ProvideItemsTask]]
    end

    if options.await then
        return awaitTaskCompletion(task) --[[@as ProvideItemsTask]]
    end

    return task
end

---@param issuedBy string
---@return ProvideItemsTaskReport
function TaskService.getProvideItemsReport(issuedBy)
    -- [todo] we're being naughty here by directly accessing TaskRepository instead of going through DatabaseSevice,
    -- but I'm kinda thinking we want to do this everywhere else anyway as I see no need for the added layering of a DatabaseService
    return TaskRepository.getProvideItemsReport(issuedBy)
end

---@class CraftItemsTaskOptions
---@field issuedBy string
---@field partOfTaskId? integer
---@field label? string
---@field items ItemStock
---@field to? InventoryHandle
---@param options CraftItemsTaskOptions
---@return CraftItemsTask
function TaskService.craftItems(options)
    local task = TaskService.findTask("craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask]]
        task.items = options.items
        task.crafted = {}
        task.to = options.to
        task = databaseService.createTask(task) --[[@as CraftItemsTask]]
    end

    return awaitTaskCompletion(task) --[[@as CraftItemsTask]]
end

---@class AllocateIngredientsTaskOptions
---@field issuedBy string
---@field items ItemStock
---@field partOfTaskId integer
---@field label? string
---@param options AllocateIngredientsTaskOptions
---@return AllocateIngredientsTask
function TaskService.allocateIngredients(options)
    local task = TaskService.findTask("allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask?]]

    if not task then
        local databaseService = Rpc.nearest(DatabaseService)
        task = constructTask(options.issuedBy, "allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask]]
        task.items = options.items
        task.missing = {}
        task = databaseService.createTask(task) --[[@as AllocateIngredientsTask]]
    end

    return awaitTaskCompletion(task) --[[@as AllocateIngredientsTask]]
end

---@class CraftFromIngredientsTaskOptions
---@field issuedBy string
---@field partOfTaskId integer
---@field label? string
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
        task.crafted = {}
        task = databaseService.createTask(task) --[[@as CraftFromIngredientsTask]]
    end

    return awaitTaskCompletion(task) --[[@as CraftFromIngredientsTask]]
end

return TaskService
