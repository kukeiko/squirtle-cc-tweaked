if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local CrafterService = require "lib.features.crafter-service"
local StorageService = require "lib.features.storage.storage-service"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"

print(string.format("[io-crafter %s] booting...", version()))

---@param usedRecipe UsedCraftingRecipe
local function usedRecipeToItemStock(usedRecipe)
    ---@type ItemStock
    local stock = {}

    for item, slots in pairs(usedRecipe.ingredients) do
        stock[item] = (stock[item] or 0) + (#slots * usedRecipe.timesUsed)
    end

    return stock
end

---@param recipe UsedCraftingRecipe
---@param bufferId integer
---@param taskBufferService TaskBufferService|RpcClient
---@param storageService StorageService|RpcClient
local function craft(recipe, bufferId, taskBufferService, storageService)
    local stash = storageService.getStashName(os.getComputerLabel())
    local ingredients = usedRecipeToItemStock(recipe)
    -- [todo] assert that everything got transferred
    taskBufferService.transferBufferStock(bufferId, {stash}, "buffer", ingredients)
    -- [todo] move craft() into this file
    CrafterService.craft(recipe, recipe.timesUsed)
    -- [todo] assert that everything got transferred
    taskBufferService.transferInventoryStockToBuffer(bufferId, stash, "buffer")
end

EventLoop.run(function()
    while true do
        local taskService = Rpc.nearest(TaskService)
        local taskBufferService = Rpc.nearest(TaskBufferService)
        local storageService = Rpc.nearest(StorageService)

        print("[wait] for new task...")
        local task = taskService.acceptCraftFromIngredientsTask(os.getComputerLabel())
        print("[yay] got a task!")
        local usedRecipes = task.usedRecipes or Utils.clone(task.craftingDetails.usedRecipes)

        print("[craft] items...")

        while #usedRecipes > 0 do
            craft(usedRecipes[1], task.bufferId, taskBufferService, storageService)
            table.remove(usedRecipes, 1)
            task.usedRecipes = usedRecipes
            taskService.updateTask(task)
        end

        print("[craft] done! flushing buffer...")
        taskBufferService.flushBuffer(task.bufferId)
        taskBufferService.freeBuffer(task.bufferId)
        -- taskService.signOffTask(task.allocateIngredientsTaskId)
        taskService.finishTask(task.id)
        print("[done] buffer empty!")
    end
end)

