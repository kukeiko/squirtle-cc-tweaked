local Utils = require "lib.common.utils"

local TaskRepository = {}

---@return string
local function getFilePath()
    return "data/entities/tasks.json"
end

---@class TaskFile
---@field id integer
---@field tasks Task[]
---@return TaskFile
local function loadFile()
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

---@param tasks Task[]
local function join(tasks)
    local taskMap = Utils.toMap(tasks, function(item)
        return item.id
    end)

    for _, task in pairs(taskMap) do
        for _, prerequisiteTaskId in pairs(task.prerequisiteIds) do
            local prerequisite = taskMap[prerequisiteTaskId]

            if not prerequisite then
                error(string.format("bad tasks data: prerequisite task #%d not found", prerequisiteTaskId))
            end

            table.insert(task.prerequisites, prerequisite)
        end
    end

    return tasks
end

---@param task Task
local function normalize(task)
    local normalized = Utils.clone(task)
    normalized.prerequisites = {}

    return normalized
end

---@param task Task
---@return Task
function TaskRepository.createTask(task)
    task = normalize(task)
    local file = loadFile()
    task.id = file.id
    file.id = file.id + 1
    table.insert(file.tasks, task)
    writeFile(file)

    return task
end

---@param task Task
function TaskRepository.updateTask(task)
    if not task.id then
        error("can't update task: no id assigned")
    end

    task = normalize(task)
    local tasks = TaskRepository.getTasks()
    local index = Utils.findIndex(tasks, function(candidate)
        return candidate.id == task.id
    end)

    if not index then
        error(string.format("can't update task: task %d doesn't exist", task.id))
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
        error(string.format("can't delete task: task %d doesn't exist", id))
    end

    table.remove(tasks, index)
    writeTasks(tasks)
end

---@return Task[]
function TaskRepository.getTasks()
    return loadFile().tasks
end

---@return Task[]
function TaskRepository.getHydratedTasks()
    local tasks = TaskRepository.getTasks()
    join(tasks)

    return tasks
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

---@param id integer
---@return Task
function TaskRepository.getHydratedTask(id)
    local task = TaskRepository.getTask(id)
    local tasks = TaskRepository.getTasks()

    join(tasks)

    return task
end

return TaskRepository
