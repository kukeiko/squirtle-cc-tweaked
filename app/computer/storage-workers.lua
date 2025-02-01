if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.common.event-loop"
local RemoteService = require "lib.common.remote-service"
local transferItemsWorker = require "lib.features.storage.workers.transfer-items-worker"
local craftItemsWorker = require "lib.features.storage.workers.craft-items-worker"
local allocateIngredientsWorker = require "lib.features.storage.workers.allocate-ingredients-worker"
local gatherItemsWorker = require "lib.features.storage.workers.gather-items-worker"
local gatherItemsViaPlayerWorker = require "lib.features.storage.workers.gather-items-via-player-worker"

local function main()
    local monitor = peripheral.find("monitor")

    if monitor then
        monitor.setTextScale(1.0)
        term.redirect(monitor)
    end

    print(string.format("[storage-workers %s] booting...", version()))

    EventLoop.runUntil("io-network:stop", function()
        transferItemsWorker()
    end, function()
        RemoteService.run({"io-network"})
    end, function()
        allocateIngredientsWorker()
    end, function()
        gatherItemsWorker()
    end, function()
        gatherItemsViaPlayerWorker()
    end, function()
        craftItemsWorker()
    end)
end

return main()
