local Utils = require "lib.tools.utils"
local TaskRepository = require "lib.database.task-repository"

---@class TaskService : Service
local TaskService = {name = "task", host = ""}

---@class TaskOptions
---@field issuedBy string
---@field partOfTaskId? integer
---@field label? string
---@field skipAwait? boolean
---@field autoDelete? boolean

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
        task = TaskRepository.getTask(task.id)
    end

    return task
end

---@param id integer
---@return Task
function TaskService.getTask(id)
    return TaskRepository.getTask(id)
end

---@param id integer
function TaskService.deleteTask(id)
    TaskRepository.deleteTask(id)
end

---@param taskType TaskType
---@param partOfTaskId integer
---@param label string
---@return Task?
function TaskService.findTask(taskType, partOfTaskId, label)
    return Utils.find(TaskRepository.getTasks(), function(task)
        return task.type == taskType and task.partOfTaskId == partOfTaskId and task.label == label
    end)
end

---@param task Task
function TaskService.updateTask(task)
    TaskRepository.updateTask(task)
end

---@param id integer
function TaskService.finishTask(id)
    TaskRepository.completeTask(id, "finished")
end

---@param id integer
function TaskService.failTask(id)
    TaskRepository.completeTask(id, "failed")
end

---@param acceptedBy string
---@param taskType TaskType
---@param exceptTaskIds? integer[]
---@return Task
function TaskService.acceptTask(acceptedBy, taskType, exceptTaskIds)
    local acceptedTask = TaskRepository.getAcceptedTask(acceptedBy, taskType, exceptTaskIds)

    if acceptedTask then
        print(string.format("[found] %s #%d", taskType, acceptedTask.id))
        return acceptedTask
    end

    local task = TaskRepository.getIssuedTask(taskType)

    if not task then
        print(string.format("[wait] for %s...", taskType))
    end

    while not task do
        os.sleep(1)
        task = TaskRepository.getIssuedTask(taskType)

        if not task then
            task = TaskRepository.getAcceptedTask(acceptedBy, taskType, exceptTaskIds)
        end
    end

    print(string.format("[found] %s #%d", taskType, task.id))

    if task.status == "issued" then
        task.acceptedBy = acceptedBy
        task.status = "accepted"
        TaskRepository.updateTask(task)
    end

    return task
end

---@class ProvideItemsTaskOptions : TaskOptions
---@field items ItemStock
---@field to InventoryHandle
---@field craftMissing boolean
---@param options ProvideItemsTaskOptions
---@return ProvideItemsTask
function TaskService.provideItems(options)
    local task = TaskRepository.findTask("provide-items", options.partOfTaskId, options.label) --[[@as ProvideItemsTask?]]

    if not task then
        task = constructTask(options.issuedBy, "provide-items", options.partOfTaskId, options.label, options.autoDelete) --[[@as ProvideItemsTask]]
        task.transferredInitial = false
        task.items = options.items
        task.to = options.to
        task.craftMissing = options.craftMissing
        task.transferred = {}
        task.crafted = {}
        task = TaskRepository.createTask(task) --[[@as ProvideItemsTask]]
    end

    if options.skipAwait then
        return task
    end

    return awaitTaskCompletion(task) --[[@as ProvideItemsTask]]
end

---@param issuedBy string
---@return ProvideItemsTaskReport
function TaskService.getProvideItemsReport(issuedBy)
    -- [todo] we're being naughty here by directly accessing TaskRepository instead of going through DatabaseSevice,
    -- but I'm kinda thinking we want to do this everywhere else anyway as I see no need for the added layering of a DatabaseService
    return TaskRepository.getProvideItemsReport(issuedBy)
end

---@class CraftItemsTaskOptions : TaskOptions
---@field items ItemStock
---@field to? InventoryHandle
---@param options CraftItemsTaskOptions
---@return CraftItemsTask
function TaskService.craftItems(options)
    local task = TaskRepository.findTask("craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask?]]

    if not task then
        task = constructTask(options.issuedBy, "craft-items", options.partOfTaskId, options.label) --[[@as CraftItemsTask]]
        task.items = options.items
        task.crafted = {}
        task.to = options.to
        task = TaskRepository.createTask(task) --[[@as CraftItemsTask]]
    end

    if options.skipAwait then
        return task
    end

    return awaitTaskCompletion(task) --[[@as CraftItemsTask]]
end

---@class AllocateIngredientsTaskOptions : TaskOptions
---@field items ItemStock
---@param options AllocateIngredientsTaskOptions
---@return AllocateIngredientsTask
function TaskService.allocateIngredients(options)
    local task = TaskRepository.findTask("allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask?]]

    if not task then
        task = constructTask(options.issuedBy, "allocate-ingredients", options.partOfTaskId, options.label) --[[@as AllocateIngredientsTask]]
        task.items = options.items
        task.missing = {}
        task = TaskRepository.createTask(task) --[[@as AllocateIngredientsTask]]
    end

    if options.skipAwait then
        return task
    end

    return awaitTaskCompletion(task) --[[@as AllocateIngredientsTask]]
end

---@class CraftFromIngredientsTaskOptions : TaskOptions
---@field craftingDetails CraftingDetails
---@field bufferId integer
---@param options CraftFromIngredientsTaskOptions
---@return CraftFromIngredientsTask
function TaskService.craftFromIngredients(options)
    local task = TaskRepository.findTask("craft-from-ingredients", options.partOfTaskId, options.label) --[[@as CraftFromIngredientsTask?]]

    if not task then
        task = constructTask(options.issuedBy, "craft-from-ingredients", options.partOfTaskId, options.label) --[[@as CraftFromIngredientsTask]]
        task.craftingDetails = options.craftingDetails
        task.bufferId = options.bufferId
        task.crafted = {}
        task = TaskRepository.createTask(task) --[[@as CraftFromIngredientsTask]]
    end

    if options.skipAwait then
        return task
    end

    return awaitTaskCompletion(task) --[[@as CraftFromIngredientsTask]]
end

---@class BuildChunkStorageTaskOptions : TaskOptions
---@field chunkX integer
---@field chunkY integer
---@param options BuildChunkStorageTaskOptions
---@return BuildChunkStorageTask
function TaskService.buildChunkStorage(options)
    local task = TaskRepository.findTask("build-chunk-storage", options.partOfTaskId, options.label) --[[@as BuildChunkStorageTask?]]

    if not task then
        task = constructTask(options.issuedBy, "build-chunk-storage", options.partOfTaskId, options.label, options.autoDelete) --[[@as BuildChunkStorageTask]]
        task.chunkX = options.chunkX
        task.chunkY = options.chunkY
        task = TaskRepository.createTask(task) --[[@as BuildChunkStorageTask]]
    end

    if options.skipAwait then
        return task
    end

    return awaitTaskCompletion(task) --[[@as BuildChunkStorageTask]]
end

return TaskService
