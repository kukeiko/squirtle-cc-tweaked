local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ItemStock = require "lib.models.item-stock"
local TaskService = require "lib.systems.task.task-service"
local StorageService = require "lib.systems.storage.storage-service"

local function work()
    local name = os.getComputerLabel()
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    print(string.format("[awaiting] next %s...", "craft-items"))
    local task = taskService.acceptTask(name, "craft-items") --[[@as CraftItemsTask]]
    print(string.format("[accepted] %s #%d", task.type, task.id))

    -- print("[busy] allocating ingredients...")
    local allocateIngredientsTask = taskService.allocateIngredients({
        issuedBy = name,
        items = task.items,
        partOfTaskId = task.id,
        label = "allocate-ingredients"
    })

    if allocateIngredientsTask.status == "failed" then
        print("[error] allocating ingredients failed")
        return taskService.failTask(task.id)
    end

    -- print("[busy] crafting from ingredients...")
    local craftFromIngredientsTask = taskService.craftFromIngredients({
        issuedBy = name,
        partOfTaskId = task.id,
        label = "craft-from-ingredients",
        bufferId = allocateIngredientsTask.bufferId,
        craftingDetails = allocateIngredientsTask.craftingDetails
    })

    if craftFromIngredientsTask.status == "failed" then
        print("[error] crafting from ingredients failed")
        return taskService.failTask(task.id)
    end

    local spillover = ItemStock.subtract(storageService.getBufferStock(allocateIngredientsTask.bufferId), task.items)

    while not Utils.isEmpty(spillover) do
        -- [todo] might transfer too much if worker crashes
        storageService.transfer(allocateIngredientsTask.bufferId, storageService.getByType("storage"), spillover)
        spillover = ItemStock.subtract(storageService.getBufferStock(allocateIngredientsTask.bufferId), task.items)
        os.sleep(5)
    end

    task.crafted = craftFromIngredientsTask.crafted
    taskService.updateTask(task)
    storageService.flushAndFreeBuffer(allocateIngredientsTask.bufferId, task.to)
    print(string.format("[finish] %s %d", task.type, task.id))
    taskService.finishTask(task.id)
end

return function()
    while true do
        work()
    end
end
