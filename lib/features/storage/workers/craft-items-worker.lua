local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"

local function work()
    local name = os.getComputerLabel()
    local taskService = Rpc.nearest(TaskService)

    print("[wait] for craft-items task...")
    local task = taskService.acceptCraftItemsTask(name)
    print(string.format("[accept] craft-items task, id #%d", task.id))

    print("[busy] allocating ingredients...")
    local allocateIngredientsTask = taskService.allocateIngredients({
        issuedBy = name,
        item = task.item,
        quantity = task.quantity,
        partOfTaskId = task.id,
        label = "allocate-ingredients"
    })

    if allocateIngredientsTask.status == "failed" then
        print("[error] allocating ingredients failed")
        return taskService.failTask(task.id)
    end

    print("[busy] crafting from ingredients...")
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

    -- [todo] currently, io-crafter is the one flushing crafted items back into the storage,
    -- but I would like this worker to do it.
    print("[done] items crafted & put into storage!")
    taskService.finishTask(task.id)
end

return function()
    while true do
        work()
    end
end
