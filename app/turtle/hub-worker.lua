if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"

local Shell = require "lib.system.shell"
local TaskWorkerPool = require "lib.system.task-worker-pool"
local DigChunkWorker = require "lib.digging.dig-chunk-worker"
local BuildChunkStorageWorker = require "lib.building.build-chunk-storage-worker"
local EmptyChunkStorageWorker = require "lib.building.empty-chunk-storage-worker"
local BuildChunkPylonWorker = require "lib.building.build-chunk-pylon-worker"

local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    local pool = TaskWorkerPool.new({BuildChunkStorageWorker, DigChunkWorker, EmptyChunkStorageWorker, BuildChunkPylonWorker})
    pool:run()
end)

app:run()
