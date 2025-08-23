local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ItemStock = require "lib.inventory.item-stock"
local TaskService = require "lib.system.task-service"
local StorageService = require "lib.inventory.storage-service"

local function work()
    local name = os.getComputerLabel()
    local taskService = Rpc.nearest(TaskService)
    local storageService = Rpc.nearest(StorageService)

    print(string.format("[awaiting] next %s...", "craft-items"))
    local task = taskService.acceptTask(name, "craft-items") --[[@as CraftItemsTask]]
    print(string.format("[accepted] %s #%d", task.type, task.id))

    local allocateIngredientsTask = taskService.allocateIngredients({issuedBy = name, items = task.items, partOfTaskId = task.id})

    if allocateIngredientsTask.status == "failed" then
        print("[error] allocating ingredients failed")
        return taskService.failTask(task.id)
    end

    local bufferId = allocateIngredientsTask.bufferId --[[@as integer]]
    local craftFromIngredientsTask = taskService.craftFromIngredients({
        issuedBy = name,
        partOfTaskId = task.id,
        bufferId = bufferId,
        craftingDetails = allocateIngredientsTask.craftingDetails
    })

    if craftFromIngredientsTask.status == "failed" then
        print("[error] crafting from ingredients failed")
        return taskService.failTask(task.id)
    end

    local craftedSpillover = ItemStock.subtract(storageService.getBufferStock(bufferId), task.items)

    if not Utils.isEmpty(craftedSpillover) then
        while not storageService.keep(bufferId, storageService.getByType("storage"), task.items) do
            os.sleep(5)
        end
    end

    task.crafted = craftFromIngredientsTask.crafted
    taskService.updateTask(task)
    storageService.flushAndFreeBuffer(bufferId, task.to)
    print(string.format("[finish] %s %d", task.type, task.id))
    taskService.finishTask(task.id)
end

return function()
    while true do
        work()
    end
end
