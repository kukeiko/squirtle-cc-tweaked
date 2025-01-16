local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"

return function()
    local taskService = Rpc.nearest(TaskService)
    local taskBufferService = Rpc.nearest(TaskBufferService)

    while true do
        print("[wait] for new task...")
        local task = taskService.acceptTask(os.getComputerLabel(), "gather-items") --[[@as GatherItemsTask]]
        print("[found] new task!", task.id)

        -- [todo] hardcoded slotCount, should be based on task-items
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id)

        if not task.bufferId then
            print("[allocate] buffer")
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
        print("[found] all items! transferring to target...")
        local _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)

        while not Utils.isEmpty(open) do
            _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)
        end

        print("[finish] task, transferred all!")
        -- [todo] if this task is interrupted after signing off gatherViaPlayerTask() and before finishTask(),
        -- it will, on resume, issue another GatherItemsViaPlayerTask.
        taskService.deleteTask(gatherViaPlayerTask.id)
        taskService.finishTask(task.id)
        taskBufferService.freeBuffer(bufferId)
    end
end
