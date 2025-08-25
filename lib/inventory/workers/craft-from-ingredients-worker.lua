local Rpc = require "lib.tools.rpc"
local TaskWorker = require "lib.system.task-worker"
local StorageService = require "lib.inventory.storage-service"
local TaskService = require "lib.system.task-service"
local CraftingApi = require "lib.inventory.crafting-api"
local TurtleApi = require "lib.turtle.turtle-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"

---@class CraftFromIngredientsTaskWorker : TaskWorker
local CraftFromIngredientsTaskWorker = {}
setmetatable(CraftFromIngredientsTaskWorker, {__index = TaskWorker})

---@param task CraftFromIngredientsTask
---@param taskService TaskService | RpcClient
---@return CraftFromIngredientsTaskWorker
function CraftFromIngredientsTaskWorker.new(task, taskService)
    local instance = TaskWorker.new(task, taskService) --[[@as CraftFromIngredientsTaskWorker]]
    setmetatable(instance, {__index = CraftFromIngredientsTaskWorker})

    return instance
end

---@return TaskType
function CraftFromIngredientsTaskWorker.getTaskType()
    return "craft-from-ingredients"
end

---@return CraftFromIngredientsTask
function CraftFromIngredientsTaskWorker:getTask()
    return self.task --[[@as CraftFromIngredientsTask]]
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

function CraftFromIngredientsTaskWorker:removeCurrentRecipe()
    local task = self:getTask()
    local recipe = task.usedRecipes[1]

    if recipe.isRoot then
        -- we don't want to report items that are only ingredients of other items
        task.crafted[recipe.item] = (task.crafted[recipe.item] or 0) + (recipe.quantity * recipe.timesUsed)
    end

    table.remove(task.usedRecipes, 1)
    self:updateTask()
end

---@param storageService StorageService|RpcClient
function CraftFromIngredientsTaskWorker:recover(storageService)
    local task = self:getTask()

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
        self:removeCurrentRecipe()
        return
    end

    -- if not, we must have ingredients in either the turtle inventory or buffer, so we just dump and return
    TurtleApi.tryDump("bottom")
end

function CraftFromIngredientsTaskWorker:work()
    local task = self:getTask()
    local storageService = Rpc.nearest(StorageService)

    if not task.usedRecipes then
        local itemDetails = storageService.getItemDetails()
        task.usedRecipes = CraftingApi.chunkUsedRecipes(task.craftingDetails.usedRecipes, TurtleApi.size(), itemDetails)
        self:updateTask()
    end

    self:recover(storageService)
    print("[craft] items...")
    local stash = os.getComputerLabel() --[[@as string]]

    -- [todo] ❌ not 100% crash safe: it is possible that an item was crafted, but the recipe for it hasn't been removed yet,
    -- so the turtle thinks (on next reboot) that ingredients are missing.
    while #task.usedRecipes > 0 do
        local recipe = task.usedRecipes[1]
        -- move ingredients from buffer to stash
        if not storageService.fulfill(task.bufferId, stash, usedRecipeToItemStock(recipe)) then
            error("ingredients in buffer went missing or buffer got detached")
        end

        -- craft items
        print(string.format("[craft] %dx %s", recipe.timesUsed * recipe.quantity, recipe.item))
        craftFromBottomInventory(recipe)
        -- manual refresh required due to turtle manipulating the stash
        storageService.refresh(stash)

        -- move crafted items from stash to buffer
        if not storageService.empty(stash, task.bufferId) then
            error("failed to empty out the stash to the buffer")
        end

        -- mark crafting step as finished
        self:removeCurrentRecipe()
    end

    print("[success] craft done!")
end

function CraftFromIngredientsTaskWorker:cleanup()
    -- [todo] ❌ figure out if cleanup is needed
end

return CraftFromIngredientsTaskWorker
