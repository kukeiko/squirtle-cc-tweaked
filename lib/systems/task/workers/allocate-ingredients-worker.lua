local Utils = require "lib.tools.utils"
local ItemStock = require "lib.models.item-stock"
local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.systems.task.task-service"
local DatabaseService = require "lib.systems.database.database-service"
local TaskBufferService = require "lib.systems.task.task-buffer-service"
local StorageService = require "lib.systems.storage.storage-service"
local CraftingApi = require "lib.apis.crafting-api"

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
                items = open,
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
