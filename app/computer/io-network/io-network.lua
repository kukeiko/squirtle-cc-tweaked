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

local function main(args)
    print("[io-network v6.0.0-dev] booting...")

    os.sleep(3)
    local run = true
    InventoryCollection.useCache = true

    EventLoop.run(function()
        Inventory.start()
    end, function()
        Rpc.server(StorageService)
    end, function()
        os.sleep(3)
        while run do
            processDrains()
            os.sleep(3)
        end
    end, function()
        os.sleep(3)
        while run do
            processFurnaces()
            os.sleep(30)
        end
    end, function()
        os.sleep(3)

        while run do
            processIo()
            os.sleep(3)
        end
    end, function()
        os.sleep(3)

        while run do
            processQuickAccess()
            os.sleep(10)
        end
    end, function()
        os.sleep(3)

        while run do
            processShulkers()
            os.sleep(3)
        end
    end, function()
        os.sleep(3)

        while run do
            processTrash()
            os.sleep(30)
        end
    end, function()
        while run do
            os.sleep(10)
            print("[refresh] storages")
            Inventory.refreshByType("storage")
        end
    end, function()
        local _, key = EventLoop.pull("key")

        if key == keys.q then
            run = false
            Inventory.stop()
        end
    end)
end

return main(arg)
