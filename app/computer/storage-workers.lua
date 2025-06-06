if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local RemoteService = require "lib.systems.runtime.remote-service"
local craftItemsWorker = require "lib.systems.task.workers.craft-items-worker"
local allocateIngredientsWorker = require "lib.systems.task.workers.allocate-ingredients-worker"
local provideItemsWorker = require "lib.systems.task.workers.provide-items-worker"

local function main()
    local monitor = peripheral.find("monitor")

    if monitor then
        monitor.setTextScale(1.0)
        term.redirect(monitor)
    end

    print(string.format("[storage-workers %s] booting...", version()))
    Utils.writeStartupFile("storage-workers")

    EventLoop.run(function()
        RemoteService.run({"storage-workers"})
    end, function()
        allocateIngredientsWorker()
    end, function()
        craftItemsWorker()
    end, function()
        provideItemsWorker()
    end)
end

return main()
