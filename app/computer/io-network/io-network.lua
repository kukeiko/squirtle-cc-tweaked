package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local Inventory = require "lib.inventory.inventory-api"
local InventoryCollection = require "lib.inventory.inventory-collection"
local QuestService = require "lib.common.quest-service"
local StorageService = require "lib.features.storage-service"
local processDrains = require "io-network.process-drains"
local processFurnaces = require "io-network.process-furnaces"
local processIo = require "io-network.process-io"
local processQuickAccess = require "io-network.process-quick-access"
local processShulkers = require "io-network.process-shulkers"
local processTrash = require "io-network.process-trash"
local processSiloOutputs = require "io-network.process-silo-outputs"
local transferItemStockQuester = require "io-network.questers.transfer-item-stock-quester"

local function main(args)
    print("[io-network v7.0.0-dev] booting...")
    InventoryCollection.useCache = true
    Inventory.discover()
    print("[io-network] ready!")

    EventLoop.runUntil("io-network:stop", function()
        Inventory.start()
    end, function()
        Rpc.server(StorageService)
    end, function()
        Rpc.server(QuestService)
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
        transferItemStockQuester()
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
