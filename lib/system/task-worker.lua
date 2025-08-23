---@class TaskWorker
---@field task Task
---@field taskService TaskService | RpcClient
local TaskWorker = {}

---@param task Task
---@param taskService TaskService | RpcClient
function TaskWorker.new(task, taskService)
    ---@type TaskWorker
    local instance = {task = task, taskService = taskService}
    setmetatable(instance, {__index = TaskWorker})

    return instance
end

---@return TaskType
function TaskWorker.getTaskType()
    error("child class did not implement getTaskType()")
end

function TaskWorker:getTaskId()
    return self.task.id
end

function TaskWorker:updateTask()
    self.taskService.updateTask(self.task)
end

---@return TaskService | RpcClient
function TaskWorker:getTaskService()
    return self.taskService
end

function TaskWorker:work()
    error("child class did not implement work()")
end

function TaskWorker:cleanup()
    error("child class did not implement cleanup()")
end

---@param items ItemStock
---@param to? InventoryHandle
---@return CraftItemsTask
function TaskWorker:craftItems(items, to)
    local task = self.taskService.craftItems({issuedBy = os.getComputerLabel(), partOfTaskId = self.task.id, items = items, to = to})

    if task.status == "failed" then
        error(string.format("%s #%d failed", task.type, task.id))
    end

    return task
end

---@param items ItemStock
---@return AllocateIngredientsTask
function TaskWorker:allocateIngredients(items)
    local task = self.taskService.allocateIngredients({issuedBy = os.getComputerLabel(), partOfTaskId = self.task.id, items = items})

    if task.status == "failed" then
        error(string.format("%s #%d failed", task.type, task.id))
    end

    return task
end

---@param craftingDetails CraftingDetails
---@param bufferId integer
function TaskWorker:craftFromIngredients(craftingDetails, bufferId)
    local task = self.taskService.craftFromIngredients({
        issuedBy = os.getComputerLabel(),
        partOfTaskId = self.task.id,
        craftingDetails = craftingDetails,
        bufferId = bufferId
    })

    if task.status == "failed" then
        error(string.format("%s #%d failed", task.type, task.id))
    end

    return task
end

return TaskWorker
