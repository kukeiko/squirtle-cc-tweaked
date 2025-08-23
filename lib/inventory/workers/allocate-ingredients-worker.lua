local Rpc = require "lib.tools.rpc"
local ItemStock = require "lib.inventory.item-stock"
local CraftingApi = require "lib.inventory.crafting-api"
local TaskService = require "lib.system.task-service"
local DatabaseService = require "lib.database.database-service"
local StorageService = require "lib.inventory.storage-service"

return function()
    local databaseService = Rpc.nearest(DatabaseService)
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print(string.format("[awaiting] next %s...", "allocate-ingredients"))
        local task = taskService.acceptTask(os.getComputerLabel(), "allocate-ingredients") --[[@as AllocateIngredientsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))
        local recipes = databaseService.getCraftingRecipes()

        if not task.bufferId then
            -- [todo] buffer leak if turtle crashes before updateTask()
            task.bufferId = storageService.allocateTaskBufferForStock(task.id, task.items)
            taskService.updateTask(task)
        end

        while true do
            local bufferStock = storageService.getBufferStock(task.bufferId)
            local storageStock = storageService.getStock()
            local availableStock = ItemStock.merge({bufferStock, storageStock})
            local craftingDetails = CraftingApi.getCraftingDetails(task.items, availableStock, recipes)
            local targetStock = ItemStock.merge({craftingDetails.available, craftingDetails.unavailable})
            task.missing = craftingDetails.unavailable
            taskService.updateTask(task)

            if storageService.fulfill(storageService.getByType("storage"), task.bufferId, targetStock) then
                task.craftingDetails = craftingDetails
                task.missing = {}
                taskService.updateTask(task)
                break
            else
                os.sleep(5)
            end
        end

        print(string.format("[finish] %s %d", task.type, task.id))
        -- no need to free/flush the buffer as it will be reused by craft-items
        taskService.finishTask(task.id)
    end
end
