if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local RemoteService = require "lib.services.remote-service"
local transferItemsWorker = require "lib.features.storage.workers.transfer-items-worker"
local craftItemsWorker = require "lib.features.storage.workers.craft-items-worker"
local allocateIngredientsWorker = require "lib.features.storage.workers.allocate-ingredients-worker"

local function main()
    local monitor = peripheral.find("monitor")

    if monitor then
        monitor.setTextScale(1.0)
        term.redirect(monitor)
    end

    print(string.format("[storage-workers %s] booting...", version()))

    EventLoop.run(function()
        RemoteService.run({"storage-workers"})
    end, function()
        transferItemsWorker()
    end, function()
        allocateIngredientsWorker()
    end, function()
        craftItemsWorker()
    end)
end

return main()
