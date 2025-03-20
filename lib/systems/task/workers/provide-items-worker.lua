local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ItemStock = require "lib.models.item-stock"
local TaskService = require "lib.systems.task.task-service"
local StorageService = require "lib.systems.storage.storage-service"

local function work()
    local name = os.getComputerLabel()
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    print(string.format("[awaiting] next %s...", "provide-items"))
    local task = taskService.acceptTask(name, "provide-items") --[[@as ProvideItemsTask]]
    print(string.format("[accepted] %s #%d", task.type, task.id))

    if not task.bufferId then
        -- [todo] buffer leak if turtle crashes before updateTask()
        task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
        taskService.updateTask(task)
    end

    if not task.transferredInitial then
        local from = storageService.getByType("storage")
        storageService.fulfill(from, task.bufferId, task.items)
        task.transferredInitial = true
        taskService.updateTask(task)
    end

    if task.craftMissing then
        local bufferStock = storageService.getBufferStock(task.bufferId)
        local open = ItemStock.subtract(task.items, bufferStock)

        if not Utils.isEmpty(open) then
            local craftItemsTask = taskService.craftItems({
                issuedBy = os.getComputerLabel(),
                label = "craft-missing-items",
                partOfTaskId = task.id,
                items = open,
                to = task.bufferId
            })

            if craftItemsTask.status == "failed" then
                print("[error] craft items failed")
                return taskService.failTask(task.id)
            end
        end
    end

    storageService.flushAndFreeBuffer(task.bufferId, task.to)
    print(string.format("[finish] %s %d", task.type, task.id))
    taskService.finishTask(task.id)
end

return function()
    while true do
        work()
    end
end
