local Utils = require "lib.tools.utils"
local ItemStock = require "lib.inventory.item-stock"

-- [todo] ❌ use EntityRepository
local TaskRepository = {}

---@return string
local function getFilePath()
    return ".kita/data/entities/tasks.json"
end

---@class TaskFile
---@field id integer
---@field tasks Task[]
---@return TaskFile
local function loadFile()
    ---@type TaskFile
    local file = Utils.readJson(getFilePath()) or {}

    if not file.id then
        file.id = 1
    end

    if not file.tasks then
        file.tasks = {}
    end

    return file
end

---@param file TaskFile
local function writeFile(file)
    Utils.writeJson(getFilePath(), file)
end

---@param tasks Task[]
local function writeTasks(tasks)
    local file = loadFile()
    file.tasks = tasks
    writeFile(file)
end

---@param task Task
---@return Task
function TaskRepository.createTask(task)
    local file = loadFile()
    task.id = file.id
    file.id = file.id + 1
    table.insert(file.tasks, task)
    writeFile(file)

    return task
end

---@param id integer
---@param status TaskStatus
function TaskRepository.completeTask(id, status)
    local tasks = TaskRepository.getTasks()
    local task = Utils.find(tasks, function(item)
        return item.id == id
    end)

    if not task then
        error(string.format("task %d doesn't exist", id))
    end

    task.status = status
    local delete = task.autoDelete and status == "finished"

    tasks = Utils.filter(tasks, function(item)
        if delete and item.id == id then
            return false
        end

        return item.partOfTaskId ~= id
    end)

    writeTasks(tasks)
end

---@param task Task
function TaskRepository.updateTask(task)
    if not task.id then
        error("can't update task: no id assigned")
    end

    local tasks = TaskRepository.getTasks()
    local index = Utils.findIndex(tasks, function(candidate)
        return candidate.id == task.id
    end)

    if not index then
        error(string.format("can't update, task %d doesn't exist", task.id))
    end

    tasks[index] = task
    writeTasks(tasks)
end

---@param id integer
function TaskRepository.deleteTask(id)
    local tasks = TaskRepository.getTasks()
    local index = Utils.findIndex(tasks, function(candidate)
        return candidate.id == id
    end)

    if not index then
        error(string.format("can't delete, task %d doesn't exist", id))
    end

    table.remove(tasks, index)
    writeTasks(tasks)
end

---@return Task[]
function TaskRepository.getTasks()
    return loadFile().tasks
end

---@param id integer
---@return Task
function TaskRepository.getTask(id)
    local task = Utils.find(TaskRepository.getTasks(), function(task)
        return task.id == id
    end)

    if not task then
        error(string.format("task %d doesn't exist", id))
    end

    return task
end

---@param acceptedBy string
---@param type TaskType
---@param exceptTaskIds? integer[]
---@return Task?
function TaskRepository.getAcceptedTask(acceptedBy, type, exceptTaskIds)
    return Utils.find(TaskRepository.getTasks(), function(task)
        return task.status == "accepted" and task.type == type and task.acceptedBy == acceptedBy and
                   (not exceptTaskIds or not Utils.contains(exceptTaskIds, task.id))
    end)
end

---@param type TaskType
---@return Task?
function TaskRepository.getIssuedTask(type)
    return Utils.find(TaskRepository.getTasks(), function(task)
        return task.type == type and task.status == "issued"
    end)
end

---@param taskType TaskType
---@param partOfTaskId integer
---@param label? string
---@return Task?
function TaskRepository.findTask(taskType, partOfTaskId, label)
    return Utils.find(TaskRepository.getTasks(), function(task)
        return task.type == taskType and task.partOfTaskId == partOfTaskId and (label == nil or task.label == label)
    end)
end

---@param taskType TaskType
---@param issuedBy? string
---@param partOfTaskId? integer
---@return Task[]
function TaskRepository.findTasks(taskType, issuedBy, partOfTaskId)
    return Utils.filter(TaskRepository.getTasks(), function(task)
        return task.type == taskType and (partOfTaskId == nil or task.partOfTaskId == partOfTaskId) and
                   (issuedBy == nil or task.issuedBy == issuedBy)
    end)
end

---@param issuedBy? string
---@param partOfTaskId? integer
---@return ProvideItemsTask[]
function TaskRepository.findProvideItemsTasks(issuedBy, partOfTaskId)
    return TaskRepository.findTasks("provide-items", issuedBy, partOfTaskId)
end

---@param partOfTaskId integer
---@return CraftItemsTask?
function TaskRepository.findCraftItemsTaskOf(partOfTaskId)
    return TaskRepository.findTask("craft-items", partOfTaskId) --[[@as CraftItemsTask?]]
end

---@param partOfTaskId integer
---@return AllocateIngredientsTask?
function TaskRepository.findAllocateIngredientsTaskOf(partOfTaskId)
    return TaskRepository.findTask("allocate-ingredients", partOfTaskId) --[[@as AllocateIngredientsTask?]]
end

---@param partOfTaskId integer
---@return CraftFromIngredientsTask?
function TaskRepository.findCraftFromIngredientsTaskOf(partOfTaskId)
    return TaskRepository.findTask("craft-from-ingredients", partOfTaskId) --[[@as CraftFromIngredientsTask?]]
end

---@param issuedBy? string
---@return ProvideItemsTaskReport
function TaskRepository.getProvideItemsReport(issuedBy)
    ---@type ProvideItemsTaskReport
    local report = {missing = {}, found = {}, wanted = {}, missingDetails = {}}
    local provideItemsTasks = TaskRepository.findProvideItemsTasks(issuedBy)

    for _, provideItemsTask in pairs(provideItemsTasks) do
        report.wanted = ItemStock.merge({report.wanted, provideItemsTask.items})
        report.found = ItemStock.merge({report.found, provideItemsTask.transferred})
        report.missing = ItemStock.merge({report.missing, provideItemsTask.missing})
        report.missingDetails = ItemStock.merge({report.missingDetails, provideItemsTask.missingDetails})
        local craftItemsTask = TaskRepository.findCraftItemsTaskOf(provideItemsTask.id)

        if craftItemsTask then
            report.found = ItemStock.merge({report.found, craftItemsTask.crafted})
            local allocateIngredientsTask = TaskRepository.findAllocateIngredientsTaskOf(craftItemsTask.id)

            if allocateIngredientsTask then
                report.missing = ItemStock.merge({report.missing, allocateIngredientsTask.missing})
            end

            local craftFromIngredientsTask = TaskRepository.findCraftFromIngredientsTaskOf(craftItemsTask.id)

            if craftFromIngredientsTask then
                report.found = ItemStock.merge({report.found, craftFromIngredientsTask.crafted})
            end
        end
    end

    -- fix report showing more items than wanted because recipes can produce more than 1x item at a time,
    -- e.g. wants 1x stick, crafts 4x => shows 4/1 instead of 1/1 without this hack
    for item, quantity in pairs(report.found) do
        if quantity > report.wanted[item] then
            report.found[item] = report.wanted[item]
        end
    end

    return report
end

return TaskRepository
