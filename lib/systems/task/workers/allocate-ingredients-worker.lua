local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ItemStock = require "lib.models.item-stock"
local CraftingApi = require "lib.apis.crafting-api"
local TaskService = require "lib.systems.task.task-service"
local DatabaseService = require "lib.systems.database.database-service"
local StorageService = require "lib.systems.storage.storage-service"

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
            task.bufferId = storageService.allocateTaskBuffer(task.id)
            taskService.updateTask(task)
        end

        while true do
            local bufferStock = storageService.getBufferStock(task.bufferId)
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

            local from = storageService.getByType("storage")

            if not storageService.fulfill(from, task.bufferId, targetStock) then
                os.sleep(5)
            end
        end

        print(string.format("[finish] %s %d", task.type, task.id))
        -- no need to free/flush the buffer as it will be reused by craft-items
        taskService.finishTask(task.id)
    end
end
