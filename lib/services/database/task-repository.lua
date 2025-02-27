local Utils = require "lib.tools.utils"

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
    tasks = Utils.filter(tasks, function(item)
        return item.partOfTaskId ~= task.id
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

return TaskRepository
