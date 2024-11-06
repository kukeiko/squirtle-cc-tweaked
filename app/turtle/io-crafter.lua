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
local DatabaseService = require "lib.common.database-service"
local StorageService = require "lib.features.storage.storage-service"
local TaskService = require "lib.common.task-service"

print(string.format("[io-crafter %s] booting...", version()))

---@param task CraftItemTask
---@param taskService TaskService|RpcClient
---@param storageService StorageService|RpcClient
---@param databaseService DatabaseService|RpcClient
---@return CraftingDetails
local function initCraftingDetails(task, taskService, storageService, databaseService)
    ---@type ItemStock
    local targetStock = {[task.item] = task.quantity}
    local storageStock = storageService.getStock()
    storageStock[task.item] = nil
    local recipes = databaseService.getCraftingRecipes()
    task.craftingDetails = CrafterService.getCraftingDetails(targetStock, storageStock, Utils.toMap(recipes, "item"))
    taskService.updateTask(task)

    return task.craftingDetails
end

---@param task CraftItemTask
---@param taskService TaskService|RpcClient
---@param storageService StorageService|RpcClient
---@return integer
local function allocateBuffer(task, taskService, storageService)
    -- [todo] hardcoded slotCount
    task.bufferId = storageService.allocateTaskBuffer(task)
    taskService.updateTask(task)
    print("allocated new buffer", task.bufferId)

    return task.bufferId
end

---@param task CraftItemTask
---@param items ItemStock
---@param buffer string[]
---@param taskService TaskService|RpcClient
---@return TransferItemsTask
local function getOrIssueTransferIngredientsTask(task, items, buffer, taskService)
    local label = "transfer-ingredients"
    -- [todo] what if task is already finished?
    local transferTask = taskService.findTransferItemTask(task.id, label)

    if not transferTask then
        transferTask = taskService.issueTransferItemsTask(os.getComputerLabel(), buffer, "buffer", items, task.id, label)
        print("issued transfer items task!")
    end

    return transferTask
end

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
---@param storageService StorageService|RpcClient
local function craft(recipe, bufferId, storageService)
    local stash = storageService.getStashName(os.getComputerLabel())
    local ingredients = usedRecipeToItemStock(recipe)
    -- [todo] assert that everything got transferred
    storageService.transferBufferStock(bufferId, {stash}, "buffer", ingredients)
    -- [todo] move craft() into this file
    CrafterService.craft(recipe, recipe.timesUsed)
    -- [todo] assert that everything got transferred
    storageService.transferInventoryStockToBuffer(bufferId, stash, "buffer")
end

EventLoop.run(function()
    while true do
        local taskService = Rpc.nearest(TaskService)
        local databaseService = Rpc.nearest(DatabaseService)
        local storageService = Rpc.nearest(StorageService)

        print("[wait] for new task...")
        local task = taskService.acceptCraftItemTask(os.getComputerLabel())
        print("[yay] got a task!")
        local craftingDetails = task.craftingDetails or initCraftingDetails(task, taskService, storageService, databaseService)

        if not Utils.isEmpty(craftingDetails.unavailable) then
            taskService.failTask(task.id)
            -- [todo] should not error out, just break/return/...
            error("missing ingredients in storage")
        end

        local bufferId = task.bufferId or allocateBuffer(task, taskService, storageService)
        local buffer = storageService.getBufferNames(bufferId)
        local transferIngredientsTask = getOrIssueTransferIngredientsTask(task, craftingDetails.available, buffer, taskService)
        transferIngredientsTask = taskService.awaitTransferItemsTaskCompletion(transferIngredientsTask)

        if not transferIngredientsTask.transferredAll then
            -- [todo] flush buffer back to storage
            taskService.failTask(task.id)
            -- [todo] should not error out, just break/return/...
            error("did not manage to fetch all ingredients")
        end

        local usedRecipes = task.usedRecipes or Utils.clone(craftingDetails.usedRecipes)

        while #usedRecipes > 0 do
            craft(usedRecipes[1], bufferId, storageService)
            table.remove(usedRecipes, 1)
            task.usedRecipes = usedRecipes
            taskService.updateTask(task)
        end

        storageService.flushBuffer(bufferId)
        storageService.freeBuffer(bufferId)
        taskService.finishTask(task.id)
    end
end)

