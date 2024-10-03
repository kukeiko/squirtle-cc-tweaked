package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local Inventory = require "lib.inventory.inventory-api"
local InventoryCollection = require "lib.inventory.inventory-collection"
local QuestService = require "lib.common.quest-service"
local StorageService = require "lib.features.storage.storage-service"
local processDrains = require "lib.features.storage.processors.process-drains"
local processFurnaces = require "lib.features.storage.processors.process-furnaces"
local processIo = require "lib.features.storage.processors.process-io"
local processQuickAccess = require "lib.features.storage.processors.process-quick-access"
local processShulkers = require "lib.features.storage.processors.process-shulkers"
local processTrash = require "lib.features.storage.processors.process-trash"
local processSiloOutputs = require "lib.features.storage.processors.process-silo-outputs"
local transferItemStockQuester = require "lib.features.storage.questers.transfer-item-stock-quester"

local function main()
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

return main()
