if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Rpc = require "lib.common.rpc"
local TaskService = require "lib.common.task-service"
print(string.format("[craft %s]", version()))

function testCrafter()
    local taskService = Rpc.nearest(TaskService)
    print("issuing crafting task")
    local task = taskService.issueCraftItemTask(os.getComputerLabel(), "minecraft:redstone_torch", 1)
    print("waiting for completion")
    task = taskService.awaitCraftItemTaskCompletion(task)
    taskService.signOffTask(task.id)
    print("task completed!", task.status)
end

testCrafter()
