if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Utils = require "lib.tools.utils"
local CraftingApi = require "lib.apis.crafting-api"
local StorageService = require "lib.systems.storage.storage-service"
local TaskService = require "lib.systems.task.task-service"
local TaskBufferService = require "lib.systems.task.task-buffer-service"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
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

---@param task CraftFromIngredientsTask
---@param storageService StorageService|RpcClient
---@param taskBufferService TaskBufferService|RpcClient
---@param taskService TaskService|RpcClient
local function recover(task, storageService, taskBufferService, taskService)
    if #task.usedRecipes == 0 then
        return
    end

    local usedRecipe = task.usedRecipes[1]

    -- if crafted item is in turtle inventory, dump turtle inventory to stash
    local turtleStock = Squirtle.getStock()

    if turtleStock[usedRecipe.item] then
        Squirtle.dump("bottom")
    end

    local stashStock = InventoryPeripheral.getStock("bottom")

    if stashStock[usedRecipe.item] then
        -- if crafted item is in stash, transfer to buffer
        local stash = storageService.resolveStash(os.getComputerLabel())
        storageService.refresh(stash)
        -- [todo] use transfer task instead, so it resizes buffer if required
        taskBufferService.dumpToBuffer(task.bufferId, stash, "buffer")
        -- => after, update task and return
        table.remove(task.usedRecipes, 1)
        taskService.updateTask(task)
        return
    end

    -- if not, we must have ingredients in either the turtle inventory or buffer, so we just dump and return
    Squirtle.dump("bottom")
end

EventLoop.run(function()
    while true do
        local taskService = Rpc.nearest(TaskService)
        local taskBufferService = Rpc.nearest(TaskBufferService)
        local storageService = Rpc.nearest(StorageService)

        print(string.format("[awaiting] next %s...", "craft-from-ingredients"))
        local task = taskService.acceptTask(os.getComputerLabel(), "craft-from-ingredients") --[[@as CraftFromIngredientsTask]]
        print(string.format("[accepted] %s #%d", task.type, task.id))

        if not task.usedRecipes then
            local itemDetails = storageService.getItemDetails()
            task.usedRecipes = CraftingApi.chunkUsedRecipes(task.craftingDetails.usedRecipes, Squirtle.size(), itemDetails)
            taskService.updateTask(task)
        end

        recover(task, storageService, taskBufferService, taskService)
        print("[craft] items...")
        local buffer = taskBufferService.getBufferNames(task.bufferId)
        local stash = storageService.resolveStash(os.getComputerLabel())

        while #task.usedRecipes > 0 do
            local recipe = task.usedRecipes[1]
            -- move ingredients from buffer to stash
            if not storageService.fulfill(buffer, "buffer", stash, "buffer", usedRecipeToItemStock(recipe), {fromSequential = true}) then
                error("ingredients in buffer went missing")
            end
            -- craft items
            craftFromBottomInventory(recipe, recipe.timesUsed)
            -- manual refresh required due to turtle manipulating the stash
            storageService.refresh(stash)
            -- move crafted items from stash to buffer
            -- [todo] assert that everything got transferred
            -- [todo] turtle doesn't reliably move items to buffer. probably caching issue in the storage.
            taskBufferService.dumpToBuffer(task.bufferId, stash, "buffer")
            -- [todo] use this instead once it accepts a "from" arguments
            -- taskService.transferItems({
            --     issuedBy = os.getComputerLabel(),
            --     items = storageService.getStockByName(stash, "buffer"),
            --     label = "dump-crafted-to-buffer",
            --     partOfTaskId = task.id,
            --     toBufferId = task.bufferId

            -- })
            -- mark crafting step as finished
            table.remove(task.usedRecipes, 1)
            taskService.updateTask(task)
        end

        print("[busy] craft done! flushing buffer...")
        taskBufferService.flushBuffer(task.bufferId)
        taskBufferService.freeBuffer(task.bufferId)
        taskService.finishTask(task.id)
        print("[done] buffer empty!")
        print(string.format("[finish] %s %d", task.type, task.id))
    end
end)

