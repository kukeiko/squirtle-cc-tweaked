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

    local success, message = pcall(function(...)
        if not task.bufferId then
            -- [todo] ❌ buffer leak if turtle crashes before updateTask()
            task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
            taskService.updateTask(task)
        end

        if not task.transferredInitial then
            local from = storageService.getByType("storage")
            local _, transferred = storageService.fulfill(from, task.bufferId, task.items)
            task.transferredInitial = true
            task.transferred = transferred
            taskService.updateTask(task)
        end

        if task.craftMissing then
            -- [todo] ❌ issues craftItems() task even if nothing needs to be crafted,
            -- meaning that just providing items (without crafting) doesn't work if no crafter is running
            local bufferStock = storageService.getBufferStock(task.bufferId)
            local open = ItemStock.subtract(task.items, bufferStock)

            if not Utils.isEmpty(open) then
                local craftItemsTask = taskService.craftItems({
                    issuedBy = os.getComputerLabel(),
                    partOfTaskId = task.id,
                    items = open,
                    to = task.bufferId
                })

                if craftItemsTask.status == "failed" then
                    print("[error] craft items failed")
                    return taskService.failTask(task.id)
                end

                task.crafted = craftItemsTask.crafted
                taskService.updateTask(task)
            end
        end

        -- [todo] ❌ support "task.to" being nil, in which case another task will take over the buffer
        storageService.flushAndFreeBuffer(task.bufferId, task.to)
        print(string.format("[finish] %s %d", task.type, task.id))
        taskService.finishTask(task.id)
    end)

    if not success then
        if task.bufferId then
            storageService.flushAndFreeBuffer(task.bufferId, task.to)
        end

        print(string.format("[failed] %s %d: %s", task.type, task.id, message))
        taskService.failTask(task.id)
    end

end

return function()
    while true do
        work()
    end
end
