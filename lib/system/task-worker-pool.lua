local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"
local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.system.task-service"

---@class TaskWorkerPool
---@field id integer
---@field maxWorkers integer
---@field availableEvent string
---@field workers TaskWorker[]
---@field taskWorkerClasses TaskWorker[]
local TaskWorkerPool = {}

---@param taskWorkerClasses TaskWorker[]
---@param maxWorkers? integer
function TaskWorkerPool.new(taskWorkerClasses, maxWorkers)
    maxWorkers = maxWorkers or 1
    local id = nextId()

    ---@type TaskWorkerPool
    local instance = {
        id = id,
        maxWorkers = maxWorkers,
        taskWorkerClasses = taskWorkerClasses,
        workers = {},
        availableEvent = string.format("task-worker-pool[%d]:available", id)
    }

    setmetatable(instance, {__index = TaskWorkerPool})

    return instance
end

function TaskWorkerPool:run()
    local taskService = Rpc.nearest(TaskService)
    local addThread, run = EventLoop.createRun()

    ---@param task Task
    local function assignTask(task)
        local workerClass = self:getTaskWorkerClassByTaskType(task.type)
        local worker = workerClass.new(task, taskService)
        table.insert(self.workers, worker)

        addThread(function()
            local success, message = pcall(function(...)
                print(string.format("[accepted] %s #%d", task.type, task.id))
                worker:work()
                print(string.format("[finish] %s #%d", task.type, task.id))
                taskService.finishTask(task.id)
            end)

            if not success then
                print(string.format("[failed] %s #%d: %s", task.type, task.id, message))
                worker:cleanup()
                taskService.failTask(task.id, message or "unknown error")
            end

            Utils.remove(self.workers, worker)
            EventLoop.queue(self.availableEvent)
        end)
    end

    addThread(function()
        local acceptedBy = os.getComputerLabel()
        local taskTypes = self:getTaskTypes()

        while self:awaitCapacity() do
            print(string.format("[awaiting] next %s...", table.concat(taskTypes, ", ")))
            local task = taskService.acceptTask(acceptedBy, taskTypes, self:getWorkerTaskIds())
            assignTask(task)
        end
    end)

    run()
end

function TaskWorkerPool:hasCapacity()
    return #self.workers < self.maxWorkers
end

---@return true
function TaskWorkerPool:awaitCapacity()
    while not self:hasCapacity() do
        EventLoop.pull(self.availableEvent)
    end

    return true
end

---@return integer[]
function TaskWorkerPool:getWorkerTaskIds()
    return Utils.map(self.workers, function(worker)
        return worker:getTaskId()
    end)
end

---@return TaskType[]
function TaskWorkerPool:getTaskTypes()
    return Utils.map(self.taskWorkerClasses, function(item)
        return item.getTaskType()
    end)
end

---@param taskType TaskType
---@return TaskWorker
function TaskWorkerPool:getTaskWorkerClassByTaskType(taskType)
    local workerClass = Utils.find(self.taskWorkerClasses, function(item, index)
        return item.getTaskType() == taskType
    end)

    if not workerClass then
        error(string.format("no worker class found for task type %s", taskType))
    end

    return workerClass
end

return TaskWorkerPool
