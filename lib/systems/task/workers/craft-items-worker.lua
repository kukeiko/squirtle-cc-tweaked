local Rpc = require "lib.tools.rpc"
local TaskService = require "lib.systems.task.task-service"

local function work()
    local name = os.getComputerLabel()
    local taskService = Rpc.nearest(TaskService)

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

    -- [todo] currently, io-crafter is the one flushing crafted items back into the storage,
    -- but I would like this worker to do it.
    print(string.format("[finish] %s %d", task.type, task.id))
    taskService.finishTask(task.id)
end

return function()
    while true do
        work()
    end
end
