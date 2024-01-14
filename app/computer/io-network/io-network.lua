package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local EventLoop = require "event-loop"
local findPeripheralSide = require "world.peripheral.find-side"
local Inventory = require "inventory.inventory"
local InventoryCollection = require "io-network.inventory-collection"
local singleOutputWorker = require "io-network.workers.single-output-worker"
local bundledOutputWorker = require "io-network.workers.bundled-output-worker"
local shulkerWorker = require "io-network.workers.shulker-worker"
local furnaceWorker = require "io-network.workers.furnace-worker"
local craftingWorker = require "io-network.workers.crafting-worker"
local refreshStoragesWorker = require "io-network.workers.refresh-storages-worker"

-- [todo] we should not only spread an item (e.g. charcoal) evenly amongst inputs,
-- but also evenly from outputs, so that e.g. the 4 lumberjack farms all start working
-- at the same time whenever charcoal is being transported away (and their outputs were full)

--- Creates an IO Inventory object for the given inventory peripheral and adds it to the collection.
--- If the inventory is a Drain, IO or Shulker inventory, the corresponding worker is also started.
---@param name string
---@param collection InventoryCollection
local function attachInventory(name, collection)
    local ioInventory = Inventory.read(name)

    if ioInventory then
        collection:add(ioInventory)

        if ioInventory.type == "drain" or ioInventory.type == "io" then
            print("[attach]", ioInventory.type)
            singleOutputWorker(collection, ioInventory, 7)
        elseif ioInventory.type == "shulker" then
            shulkerWorker(collection, ioInventory)
        end
    end
end

local function main(args)
    print("[io-network v4.3.0-dev] booting...")
    local timeout = tonumber(args[1] or 30) or 30
    local modem = findPeripheralSide("modem")

    if not modem then
        error("no modem found")
    end

    local collection = InventoryCollection.new()

    EventLoop.run(function()
        for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
            EventLoop.queue("peripheral", name)
        end
    end, function()
        while true do
            EventLoop.pull("peripheral", function(_, name)
                attachInventory(name, collection)
            end)
        end
    end, function()
        while true do
            local _, name = EventLoop.pull("peripheral_detach")
            print("[detach]", name)
            collection:remove(name)
        end
    end, function()
        -- [todo] why sleep? I think it was to have inventories be initialized before the worker runs.
        -- if that is the case, then it doesn't work reliably: I had a case where it didn't find any input
        -- inventories during first cycle of the furnace worker.
        os.sleep(1)
        furnaceWorker(collection, 7)
    end, function()
        bundledOutputWorker(collection, "silo", 7)
    end, function()
        craftingWorker(collection)
    end, function()
        refreshStoragesWorker(collection, timeout)
    end)
end

return main(arg)
