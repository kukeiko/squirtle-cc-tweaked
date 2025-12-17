if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Shell = require "lib.system.shell"
local TaskWorkerPool = require "lib.system.task-worker-pool"
local CraftFromIngredientsTaskWorker = require "lib.inventory.workers.craft-from-ingredients-worker"

local app = Shell.getApplication(arg)

print(string.format("[io-crafter %s] booting...", version()))

app:addWindow("Main", function()
    TaskWorkerPool.new(CraftFromIngredientsTaskWorker, 1):run()
end)

app:addLogsWindow()
app:run()
