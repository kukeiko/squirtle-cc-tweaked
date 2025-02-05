local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"
local StorageService = require "lib.features.storage.storage-service"

return function()
    local taskService = Rpc.nearest(TaskService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print(string.format("[awaiting] next %s...", "gather-items"))
        local task = taskService.acceptTask(os.getComputerLabel(), "gather-items") --[[@as GatherItemsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))
        local requiredSlotCount = storageService.getRequiredSlotCount(task.items)
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id, requiredSlotCount)

        if not task.bufferId then
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        -- [todo] for now this just creates a task for the player to gather the items.
        -- in the future, this worker should check which farms/factories are available to produce items and create tasks for those.
        local gatherViaPlayerTask = taskService.gatherItemsViaPlayer({
            issuedBy = os.getComputerLabel(),
            items = task.items,
            to = taskBufferService.getBufferNames(bufferId),
            toTag = "buffer",
            label = "gather-via-player",
            partOfTaskId = task.id
        })

        -- [todo] checking statuses is done sparingly throughout task code - should fix that up properly
        if gatherViaPlayerTask.status == "failed" then
            taskService.failTask(task.id)
            error("gather items via player task failed")
        end

        -- [todo] move to target inventory
        -- print("[found] all items! transferring to target...")
        local _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)

        while not Utils.isEmpty(open) do
            _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)
        end

        print(string.format("[finish] %s %d", task.type, task.id))
        -- [todo] if this task is interrupted after signing off gatherViaPlayerTask() and before finishTask(),
        -- it will, on resume, issue another GatherItemsViaPlayerTask.
        taskService.deleteTask(gatherViaPlayerTask.id)
        taskService.finishTask(task.id)
        taskBufferService.freeBuffer(bufferId)
    end
end
