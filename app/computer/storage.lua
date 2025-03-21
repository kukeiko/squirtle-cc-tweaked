if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Inventory = require "lib.apis.inventory.inventory-api"
local StorageService = require "lib.systems.storage.storage-service"
local RemoteService = require "lib.systems.runtime.remote-service"
local processDumps = require "lib.systems.storage.processors.process-dumps"
local processFurnaces = require "lib.systems.storage.processors.process-furnaces"
local processIo = require "lib.systems.storage.processors.process-io"
local processQuickAccess = require "lib.systems.storage.processors.process-quick-access"
local processShulkers = require "lib.systems.storage.processors.process-shulkers"
local processTrash = require "lib.systems.storage.processors.process-trash"
local processSiloOutputs = require "lib.systems.storage.processors.process-silo-outputs"

local function main()
    local monitor = peripheral.find("monitor")

    if monitor then
        monitor.setTextScale(1.0)
        term.redirect(monitor)
    end

    print(string.format("[storage %s] booting...", version()))
    Inventory.useCache(true)
    Inventory.discover()
    print("[storage] ready!")
    Utils.writeStartupFile("storage")

    EventLoop.runUntil("storage:stop", function()
        Inventory.start()
    end, function()
        RemoteService.run({"storage"})
    end, function()
        Rpc.host(StorageService)
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
            print("[stop] storage")
            Inventory.stop()
            EventLoop.queue("storage:stop")
        end
    end)
end

return main()
