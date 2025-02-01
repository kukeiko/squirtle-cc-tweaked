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
local StorageService = require "lib.features.storage.storage-service"
local TaskService = require "lib.common.task-service"
local TaskBufferService = require "lib.common.task-buffer-service"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Squirtle = require "lib.squirtle.squirtle-api"

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

-- [todo] check that sufficient crafting materials are provided
---@param recipe CraftingRecipe
---@param quantity integer
local function craftFromBottomInventory(recipe, quantity)
    local inventory = "bottom"
    local workbench = peripheral.find("workbench")

    if not workbench then
        error("no crafting table equipped :(")
    end

    for item, slots in pairs(recipe.ingredients) do
        for _, recipeSlot in pairs(slots) do
            local inventorySlot = InventoryPeripheral.findItem(inventory, item)

            if not inventorySlot then
                error(string.format("item %s missing in chest", item))
            end

            local turtleSlot = recipeSlot + math.ceil(recipeSlot / 3) - 1
            Squirtle.select(turtleSlot)
            Squirtle.suckSlot(inventory, inventorySlot, quantity)
        end
    end

    workbench.craft()
    Squirtle.dump(inventory)
end

---@param recipe UsedCraftingRecipe
---@param bufferId integer
---@param taskBufferService TaskBufferService|RpcClient
---@param storageService StorageService|RpcClient
local function craft(recipe, bufferId, taskBufferService, storageService)
    local stash = storageService.getStashName(os.getComputerLabel())
    local ingredients = usedRecipeToItemStock(recipe)
    -- [todo] assert that everything got transferred
    -- [todo] should instead be "transfer until target stock is reached", to make it crash safe
    taskBufferService.transferBufferStock(bufferId, {stash}, "buffer", ingredients)
    craftFromBottomInventory(recipe, recipe.timesUsed)
    -- [todo] hack
    storageService.refreshInventories({stash})
    -- [todo] assert that everything got transferred
    -- [todo] turtle doesn't reliably move items to buffer. probably caching issue in the storage.
    taskBufferService.transferInventoryStockToBuffer(bufferId, stash, "buffer")
end

EventLoop.run(function()
    while true do
        local taskService = Rpc.nearest(TaskService)
        local taskBufferService = Rpc.nearest(TaskBufferService)
        local storageService = Rpc.nearest(StorageService)

        print("[wait] for new task...")
        local task = taskService.acceptTask(os.getComputerLabel(), "craft-from-ingredients") --[[@as CraftFromIngredientsTask]]
        print(string.format("[accepted] task #%d", task.id))
        -- [todo] we don't need the "craftingDetails" property at all - remove it and just use "usedRecipes"
        local usedRecipes = task.usedRecipes or Utils.clone(task.craftingDetails.usedRecipes)
        print("[craft] items...")

        while #usedRecipes > 0 do
            -- [todo] not crash safe: if turtle crafted items and crashes during it, "usedRecipes" is not updated and it will
            -- try to craft the same recipe again on reboot. there are also others cases where it is not crash safe, so...
            -- needs a complete overhaul probably. for now its fine because I don't expect to reboot crafting turtles.
            craft(usedRecipes[1], task.bufferId, taskBufferService, storageService)
            table.remove(usedRecipes, 1)
            task.usedRecipes = usedRecipes
            taskService.updateTask(task)
        end

        print("[craft] done! flushing buffer...")
        taskBufferService.flushBuffer(task.bufferId)
        taskBufferService.freeBuffer(task.bufferId)
        taskService.finishTask(task.id)
        print("[done] buffer empty!")
    end
end)

