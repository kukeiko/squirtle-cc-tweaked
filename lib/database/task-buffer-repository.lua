local Utils = require "lib.tools.utils"

local TaskBufferRepository = {}

---@return string
local function getFilePath()
    return "data/entities/task-buffers.json"
end

---@class TaskBufferFile
---@field id integer
---@field taskBuffers TaskBuffer[]
---@return TaskBufferFile
local function loadFile()
    ---@type TaskBufferFile
    local file = Utils.readJson(getFilePath()) or {}

    if not file.id then
        file.id = 1
    end

    if not file.taskBuffers then
        file.taskBuffers = {}
    end

    return file
end

---@param file TaskBufferFile
local function writeFile(file)
    Utils.writeJson(getFilePath(), file)
end

---@param taskBuffers TaskBuffer[]
local function writeTaskBuffers(taskBuffers)
    local file = loadFile()
    file.taskBuffers = taskBuffers
    writeFile(file)
end

---@param taskId integer
---@param inventories string[]
---@return TaskBuffer
function TaskBufferRepository.createTaskBuffer(inventories, taskId)
    local file = loadFile()
    ---@type TaskBuffer
    local taskBuffer = {id = file.id, inventories = inventories, taskId = taskId}
    file.id = file.id + 1
    table.insert(file.taskBuffers, taskBuffer)
    writeFile(file)

    return taskBuffer
end

---@return TaskBuffer[]
function TaskBufferRepository.getTaskBuffers()
    return loadFile().taskBuffers
end

---@param id integer
---@return TaskBuffer
function TaskBufferRepository.getTaskBuffer(id)
    local taskBuffer = Utils.find(TaskBufferRepository.getTaskBuffers(), function(taskBuffer)
        return taskBuffer.id == id
    end)

    if not taskBuffer then
        error(string.format("task-buffer %d doesn't exist", id))
    end

    return taskBuffer
end

---@param taskId integer
---@return TaskBuffer?
function TaskBufferRepository.findTaskBufferByTaskId(taskId)
    return Utils.find(TaskBufferRepository.getTaskBuffers(), function(candidate)
        return candidate.taskId == taskId
    end)
end

---@param taskBuffer TaskBuffer
function TaskBufferRepository.updateTaskBuffer(taskBuffer)
    if not taskBuffer.id then
        error("can't update task-buffer: no id assigned")
    end

    local taskBuffers = TaskBufferRepository.getTaskBuffers()
    local index = Utils.findIndex(taskBuffers, function(candidate)
        return candidate.id == taskBuffer.id
    end)

    if not index then
        error(string.format("can't update, task-buffer %d doesn't exist", taskBuffer.id))
    end

    taskBuffers[index] = taskBuffer
    writeTaskBuffers(taskBuffers)
end

---@param bufferId integer
function TaskBufferRepository.deleteTaskBuffer(bufferId)
    local taskBuffers = TaskBufferRepository.getTaskBuffers()
    local index = Utils.findIndex(taskBuffers, function(candidate)
        return candidate.id == bufferId
    end)

    if not index then
        error(string.format("can't delete, task-buffer %d doesn't exist", bufferId))
    end

    table.remove(taskBuffers, index)
    writeTaskBuffers(taskBuffers)
end

return TaskBufferRepository
