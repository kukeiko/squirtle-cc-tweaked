if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local CraftingApi = require "lib.apis.crafting-api"
local StorageService = require "lib.systems.storage.storage-service"
local RemoteService = require "lib.systems.runtime.remote-service"
local TaskService = require "lib.systems.task.task-service"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local Shell = require "lib.ui.shell"
local showLogs = require "lib.ui.windows.show-logs"

print(string.format("[io-crafter %s] booting...", version()))
Utils.writeStartupFile("io-crafter")

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
local function craftFromBottomInventory(recipe)
    local inventory = "bottom"
    local workbench = peripheral.find("workbench")

    if not workbench then
        error("no crafting table equipped :(")
    end

    for item, slots in pairs(recipe.ingredients) do
        for _, recipeSlot in pairs(slots) do
            local turtleSlot = recipeSlot + math.ceil(recipeSlot / 3) - 1
            TurtleApi.select(turtleSlot)

            if not TurtleApi.suckItem(inventory, item, recipe.timesUsed) then
                error(string.format("item %s missing in chest", item))
            end
        end
    end

    workbench.craft()
    TurtleApi.tryDump(inventory)
end

---@param task CraftFromIngredientsTask
---@param taskService TaskService|RpcClient
local function removeCurrentRecipe(task, taskService)
    local recipe = task.usedRecipes[1]

    if recipe.isRoot then
        -- we don't want to report items that are only ingredients of other items
        task.crafted[recipe.item] = (task.crafted[recipe.item] or 0) + (recipe.quantity * recipe.timesUsed)
    end

    table.remove(task.usedRecipes, 1)
    taskService.updateTask(task)
end

---@param task CraftFromIngredientsTask
---@param storageService StorageService|RpcClient
---@param taskService TaskService|RpcClient
local function recover(task, storageService, taskService)
    if #task.usedRecipes == 0 then
        return
    end

    local usedRecipe = task.usedRecipes[1]
    -- if crafted item is in turtle inventory, dump turtle inventory to stash
    local turtleStock = TurtleApi.getStock()

    if turtleStock[usedRecipe.item] then
        TurtleApi.tryDump("bottom")
    end

    local stashStock = InventoryPeripheral.getStock("bottom")

    if stashStock[usedRecipe.item] then
        -- if crafted item is in stash, transfer to buffer
        local stash = os.getComputerLabel()
        storageService.refresh(stash)

        if not storageService.empty(stash, task.bufferId) then
            error("failed to empty out the stash to the buffer")
        end

        -- after, update task and return
        removeCurrentRecipe(task, taskService)
        return
    end

    -- if not, we must have ingredients in either the turtle inventory or buffer, so we just dump and return
    TurtleApi.tryDump("bottom")
end

Shell:addWindow("Main", function()
    while true do
        local taskService = Rpc.nearest(TaskService)
        local storageService = Rpc.nearest(StorageService)

        print(string.format("[awaiting] next %s...", "craft-from-ingredients"))
        local task = taskService.acceptTask(os.getComputerLabel(), "craft-from-ingredients") --[[@as CraftFromIngredientsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))

        if not task.usedRecipes then
            local itemDetails = storageService.getItemDetails()
            task.usedRecipes = CraftingApi.chunkUsedRecipes(task.craftingDetails.usedRecipes, TurtleApi.size(), itemDetails)
            taskService.updateTask(task)
        end

        recover(task, storageService, taskService)
        print("[craft] items...")
        local stash = os.getComputerLabel()

        while #task.usedRecipes > 0 do
            local recipe = task.usedRecipes[1]
            -- move ingredients from buffer to stash
            if not storageService.fulfill(task.bufferId, stash, usedRecipeToItemStock(recipe)) then
                error("ingredients in buffer went missing or buffer got detached")
            end

            -- craft items
            craftFromBottomInventory(recipe)
            -- manual refresh required due to turtle manipulating the stash
            storageService.refresh(stash)

            -- move crafted items from stash to buffer
            if not storageService.empty(stash, task.bufferId) then
                error("failed to empty out the stash to the buffer")
            end

            -- mark crafting step as finished
            removeCurrentRecipe(task, taskService)
        end

        print("[success] craft done!")
        taskService.finishTask(task.id)
        print(string.format("[finish] %s %d", task.type, task.id))
    end
end)

Shell:addWindow("Logs", showLogs)

Shell:addWindow("Remote", function()
    RemoteService.run({"io-crafter"})
end)

Shell:run()

