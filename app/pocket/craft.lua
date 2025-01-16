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
    print("[wait] for crafting to be complete...")
    local task = taskService.craftItems({issuedBy = os.getComputerLabel(), item = "minecraft:redstone_torch", quantity = 1})
    print("[done] items crafted!")
    taskService.deleteTask(task.id)
    print("task completed!", task.status)
end

testCrafter()
