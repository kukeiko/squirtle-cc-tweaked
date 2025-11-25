if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local RemoteService = require "lib.system.remote-service"
local Shell = require "lib.system.shell"
local showLogs = require "lib.system.windows.logs-window"
local TaskWorkerPool = require "lib.system.task-worker-pool"
local CraftFromIngredientsTaskWorker = require "lib.inventory.workers.craft-from-ingredients-worker"

print(string.format("[io-crafter %s] booting...", version()))
Utils.writeStartupFile("io-crafter")

Shell:addWindow("Main", function()
    TaskWorkerPool.new(CraftFromIngredientsTaskWorker, 1):run()
end)

Shell:addWindow("Logs", showLogs)

Shell:addWindow("Remote", function()
    RemoteService.run({"io-crafter"})
end)

Shell:run()

