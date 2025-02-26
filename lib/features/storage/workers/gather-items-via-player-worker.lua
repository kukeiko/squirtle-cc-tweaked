local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local ItemStock = require "lib.common.models.item-stock"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"
local StorageService = require "lib.features.storage.storage-service"

return function()
    local taskService = Rpc.nearest(TaskService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print(string.format("[awaiting] next %s...", "gather-items-via-player"))
        local task = taskService.acceptTask(os.getComputerLabel(), "gather-items-via-player") --[[@as GatherItemsViaPlayerTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))
        local requiredSlotCount = storageService.getRequiredSlotCount(task.items)
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id, requiredSlotCount)

        if not task.bufferId then
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        if not ItemStock.isEmpty(task.open) then
            print("[transfer] items...")
        end

        while not ItemStock.isEmpty(task.open) do
            -- [todo] here it is possible that we're reusing an existing transfer-items task that differs in "targetStock".
            -- that can happen when this worker reboots while the transfer task is moving the items from its own buffer to this tasks' buffer.
            -- mentioning this because within the transferItems() method I do have another todo note questioning what to do in that case
            Utils.prettyPrint(task.open)
            local transferTask = taskService.transferItems({
                issuedBy = os.getComputerLabel(),
                items = task.open,
                to = taskBufferService.getBufferNames(bufferId),
                toTag = "buffer",
                label = "transfer-player-gathered-items",
                partOfTaskId = task.id
            })

            -- [todo] deleting here is unsafe in case unload happens, as we're using "task.open" to figure out whats missing.
            -- maybe it is better to not rely on "task.open" at all, and instead read buffer stock all the time?
            taskService.deleteTask(transferTask.id)

            if not ItemStock.isEmpty(transferTask.transferred) then
                print("[found] items, updating remaining items")
                task.open = ItemStock.subtract(task.items, taskBufferService.getBufferStock(bufferId))
                taskService.updateTask(task)
            end

            if not ItemStock.isEmpty(task.open) then
                os.sleep(3)
            end
        end

        print("[found] all items! transferring to target...")
        local _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)

        while not Utils.isEmpty(open) do
            _, open = taskBufferService.transferBufferStock(bufferId, task.to, task.toTag)
        end

        print(string.format("[finish] %s %d", task.type, task.id))
        taskService.finishTask(task.id)
        taskBufferService.freeBuffer(bufferId)
    end
end
