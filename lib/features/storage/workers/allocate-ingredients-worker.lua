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
        print("[wait] for new task...")
        local task = taskService.acceptTask(os.getComputerLabel(), "allocate-ingredients") --[[@as AllocateIngredientsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))

        if not task.craftingDetails then
            print("[recipe] initialize crafting details")
            local recipes = databaseService.getCraftingRecipes()
            local recipesMap = Utils.toMap(recipes, function(item)
                return item.item
            end)

            local storageStock = storageService.getStock()

            for item in pairs(task.items) do
                storageStock[item] = nil
            end

            task.craftingDetails = CraftingApi.getCraftingDetails(task.items, storageStock, recipesMap)
            taskService.updateTask(task)
        end

        local totalStock = ItemStock.merge({task.craftingDetails.available, task.craftingDetails.unavailable})
        -- [todo] hardcoded slotCount, should be based on totalStock
        local bufferId = task.bufferId or taskBufferService.allocateTaskBuffer(task.id)

        if not task.bufferId then
            print("[allocate] buffer")
            task.bufferId = bufferId
            taskService.updateTask(task)
        end

        local transferTask = taskService.transferItems({
            issuedBy = os.getComputerLabel(),
            to = taskBufferService.getBufferNames(bufferId),
            toTag = "buffer",
            targetStock = task.craftingDetails.available,
            partOfTaskId = task.id,
            label = "transfer-ingredients"
        })

        if transferTask.status == "failed" then
            taskService.failTask(task.id)
            -- [todo] this worker should not error out
            error("transfer-items task failed")
        end

        if not transferTask.transferredAll then
            taskService.failTask(task.id)
            -- [todo] implement the magic solution to adapt to new stock
            error("recovery not yet implemented: ingredients got lost during transfer")
        end

        ---@type GatherItemsTask?
        local gatherItemsTask

        if not ItemStock.isEmpty(task.craftingDetails.unavailable) then
            gatherItemsTask = taskService.gatherItems({
                issuedBy = os.getComputerLabel(),
                items = task.craftingDetails.unavailable,
                to = taskBufferService.getBufferNames(bufferId),
                toTag = "buffer",
                label = "gather-ingredients",
                partOfTaskId = task.id
            })

            if gatherItemsTask.status == "failed" then
                taskService.failTask(task.id)
                error("failed to gather ingredients")
            end
        end

        -- no need to free/flush the buffer as it will be reused by craft-items
        taskService.finishTask(task.id)
    end
end
