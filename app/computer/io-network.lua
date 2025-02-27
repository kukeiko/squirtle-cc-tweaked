if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TaskBufferService = require "lib.services.task-buffer-service"
local Inventory = require "lib.apis.inventory-api"
local StorageService = require "lib.features.storage.storage-service"
local RemoteService = require "lib.services.remote-service"
local processDumps = require "lib.features.storage.processors.process-dumps"
local processFurnaces = require "lib.features.storage.processors.process-furnaces"
local processIo = require "lib.features.storage.processors.process-io"
local processQuickAccess = require "lib.features.storage.processors.process-quick-access"
local processShulkers = require "lib.features.storage.processors.process-shulkers"
local processTrash = require "lib.features.storage.processors.process-trash"
local processSiloOutputs = require "lib.features.storage.processors.process-silo-outputs"

local function main()
    local monitor = peripheral.find("monitor")

    if monitor then
        monitor.setTextScale(1.0)
        term.redirect(monitor)
    end

    print(string.format("[io-network %s] booting...", version()))
    Inventory.useCache(true)
    Inventory.discover()
    print("[io-network] ready!")
    -- [todo] storage on kunterbunt redirects to a monitor on startup, so we can't use this yet
    -- Utils.writeStartupFile("io-network")

    EventLoop.runUntil("io-network:stop", function()
        Inventory.start()
    end, function()
        RemoteService.run({"io-network"})
    end, function()
        Rpc.host(StorageService)
    end, function()
        Rpc.host(TaskBufferService)
    end, function()
        while true do
            processDumps()
            os.sleep(3)
        end
    end, function()
        while true do
            processFurnaces()
            os.sleep(30)
        end
    end, function()
        while true do
            processIo()
            os.sleep(3)
        end
    end, function()
        while true do
            processQuickAccess()
            os.sleep(10)
        end
    end, function()
        while true do
            processShulkers()
            os.sleep(3)
        end
    end, function()
        while true do
            processTrash()
            os.sleep(30)
        end
    end, function()
        while true do
            processSiloOutputs()
            os.sleep(10)
        end
    end, function()
        while true do
            os.sleep(10)
            print("[refresh] storages, silos & stashes")
            Inventory.refresh("storage")
            Inventory.refresh("silo:input")
            Inventory.refresh("stash")
        end
    end, function()
        local _, key = EventLoop.pull("key")

        if key == keys.f4 then
            print("[stop] io-network")
            Inventory.stop()
            EventLoop.queue("io-network:stop")
        end
    end)
end

return main()
