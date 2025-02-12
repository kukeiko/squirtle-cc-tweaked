local Utils = require "lib.common.utils"
local ItemStock = require "lib.common.models.item-stock"
local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"
local DatabaseService = require "lib.common.database-service"
local TaskBufferService = require "lib.common.task-buffer-service"
local StorageService = require "lib.features.storage.storage-service"
local CraftingApi = require "lib.common.crafting-api"

return function()
    local databaseService = Rpc.nearest(DatabaseService)
    local taskService = Rpc.nearest(TaskService)
    local taskBufferService = Rpc.nearest(TaskBufferService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print(string.format("[awaiting] next %s...", "allocate-ingredients"))
        local task = taskService.acceptTask(os.getComputerLabel(), "allocate-ingredients") --[[@as AllocateIngredientsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))
        local recipes = databaseService.getCraftingRecipes()

        if not task.bufferId then
            task.bufferId = taskBufferService.allocateTaskBuffer(task.id)
            taskService.updateTask(task)
        end

        while true do
            local bufferStock = taskBufferService.getBufferStock(task.bufferId)
            local storageStock = storageService.getStock()

            -- [todo] if we want to craft repeaters and redstone torches, we might unnecessarily craft redstone torches
            -- for the repeaters, just because we also want to craft redstone torches.
            for item in pairs(task.items) do
                storageStock[item] = nil
            end

            local currentStock = ItemStock.merge({bufferStock, storageStock})
            local craftingDetails = CraftingApi.getCraftingDetails(task.items, currentStock, recipes)
            local targetStock = ItemStock.merge({craftingDetails.available, craftingDetails.unavailable})
            -- the obsoleteStock remains in buffer until "craft-from-ingredients" task flushed the buffer (which is reused across the tasks)
            local obsoleteStock = ItemStock.subtract(bufferStock, targetStock)
            -- local requiredSlotCount = storageService.getRequiredSlotCount(ItemStock.merge({targetStock, obsoleteStock}))
            -- [todo] it is possbile that the requiredSlotCount for crafted items is higher than that of the ingredients,
            -- example: 1x stack of glass crafted to 2.5x stacks of glass panes.
            -- in addition, intermediate crafts might also need more slots. if we were to allocate summed slots for all intermediate crafts,
            -- the buffer size will explode. it is a fringe edge case but should be considered nonetheless.
            -- [idea] maybe instead of pre-allocation and then transferring, we just let the transfer-items task handle allocation as needed.
            -- taskBufferService.resize(task.bufferId, requiredSlotCount)
            -- [todo] update in a service the wanted items of this task (crafting.unavailable)
            local open = ItemStock.subtract(targetStock, bufferStock)

            if Utils.isEmpty(open) then
                task.craftingDetails = craftingDetails
                taskService.updateTask(task)
                break
            end

            local transferTask = taskService.transferItems({
                issuedBy = os.getComputerLabel(),
                toBufferId = task.bufferId,
                targetStock = open,
                partOfTaskId = task.id,
                label = "transfer-ingredients"
            })

            if transferTask.status == "failed" then
                taskService.failTask(task.id)
                -- [todo] this worker should not error out
                -- [todo] flush & free buffer
                error("transfer-items task failed")
            end

            if not transferTask.transferredAll then
                taskService.deleteTask(transferTask.id)
                os.sleep(5)
            end
        end

        print(string.format("[finish] %s %d", task.type, task.id))
        -- no need to free/flush the buffer as it will be reused by craft-items
        taskService.finishTask(task.id)
    end
end
