package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local EventLoop = require "event-loop"
local Rpc = require "rpc"
local Inventory = require "inventory"
local InventoryCollection = require "inventory.inventory-collection"
local StorageService = require "services.storage-service"
local processDrains = require "io-network.process-drains"
local processFurnaces = require "io-network.process-furnaces"
local processIo = require "io-network.process-io"
local processQuickAccess = require "io-network.process-quick-access"
local processShulkers = require "io-network.process-shulkers"
local processTrash = require "io-network.process-trash"
local processSiloOutputs = require "io-network.process-silo-outputs"

local function main(args)
    print("[io-network v6.3.1-dev] booting...")
    InventoryCollection.useCache = true
    Inventory.discover()
    print("[io-network] ready!")

    EventLoop.runUntil("io-network:stop", function()
        Inventory.start()
    end, function()
        Rpc.server(StorageService)
    end, function()
        while true do
            processDrains()
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
            print("[refresh] storages & silos")
            Inventory.refreshByType("storage")
            Inventory.refreshByType("silo:input")
            Inventory.refreshByType("silo:output")
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

return main(arg)
