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
local Rpc = require "lib.tools.rpc"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local Inventory = require "lib.apis.inventory.inventory-api"
local InventoryCollection = require "lib.apis.inventory.inventory-collection"
local StorageService = require "lib.systems.storage.storage-service"
local RemoteService = require "lib.systems.runtime.remote-service"
local processDumps = require "lib.systems.storage.processors.process-dumps"
local processFurnaces = require "lib.systems.storage.processors.process-furnaces"
local processIo = require "lib.systems.storage.processors.process-io"
local processQuickAccess = require "lib.systems.storage.processors.process-quick-access"
local processShulkers = require "lib.systems.storage.processors.process-shulkers"
local processTrash = require "lib.systems.storage.processors.process-trash"
local processSiloOutputs = require "lib.systems.storage.processors.process-silo-outputs"
local TurtleInventoryAdapter = require "lib.systems.storage.turtle-inventory-adapter"
local logsWindow = require "lib.systems.shell.windows.logs-window"
local eventLoopWindow = require "lib.systems.shell.windows.event-loop-window"
local activeLocksWindow = require "lib.systems.storage.windows.active-locks-window"
local activeUnlocksWindow = require "lib.systems.storage.windows.active-unlocks-window"
local processorsWindow = require "lib.systems.storage.windows.processors-window"

local function refresh()
    print("[refresh] storages, silos & stashes")
    Inventory.refresh("storage")
    Inventory.refresh("silo:input")
    Inventory.refresh("stash")
end

---@class StorageProcessorOption
---@field enabled boolean
---@field interval integer
---@field fn fun() : nil
---
---@class StorageProcessorOptions
---@field dumps StorageProcessorOption
---@field furnaces StorageProcessorOption
---@field io StorageProcessorOption
---@field quickAccess StorageProcessorOption
---@field shulkers StorageProcessorOption
---@field trash StorageProcessorOption
---@field siloOutputs StorageProcessorOption
---@field refresh StorageProcessorOption
local processors = {
    dumps = {enabled = true, fn = processDumps, interval = 3},
    furnaces = {enabled = true, fn = processFurnaces, interval = 30},
    io = {enabled = true, fn = processIo, interval = 3},
    quickAccess = {enabled = true, fn = processQuickAccess, interval = 10},
    shulkers = {enabled = true, fn = processShulkers, interval = 3},
    trash = {enabled = true, fn = processTrash, interval = 30},
    siloOutputs = {enabled = true, fn = processSiloOutputs, interval = 10},
    refresh = {enabled = true, fn = refresh, interval = 10}
}

local function main()
    print(string.format("[storage %s] booting...", version()))
    InventoryPeripheral.addAdapter(TurtleInventoryAdapter)
    Inventory.useCache(true)
    Inventory.discover()
    print("[storage] ready!")
    Utils.writeStartupFile(string.format("storage%s", arg[1] and " " .. arg[1] or ""))

    local processorFns = Utils.map(processors, function(processor)
        return function()
            while true do
                if processor.enabled then
                    processor.fn()
                end

                os.sleep(processor.interval)
            end
        end
    end)

    EventLoop.runUntil("storage:stop", function()
        Inventory.start(arg[1])
    end, function()
        EventLoop.pullKey(keys.f4)
        print("[stop] storage")
        Inventory.stop()
        EventLoop.queue("storage:stop")
    end, function()
        while true do
            EventLoop.pullKey(keys.f3)
            print("[dump] cache to disk")
            local cache = Utils.clone(InventoryCollection.getCache())

            for _, inventory in pairs(cache) do
                inventory.slots = nil
            end

            Utils.writeJson("storage-cache-dump.json", cache)
        end
    end, table.unpack(processorFns))
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(1.0)
    term.redirect(monitor)
end

term.clear()

local Shell = require "lib.ui.shell"

Shell:addWindow("Main", main)
Shell:addWindow("Logs", logsWindow)

Shell:addWindow("RPC", function()
    EventLoop.run(function()
        RemoteService.run({"storage"})
    end, function()
        Rpc.host(StorageService)
    end)
end)

Shell:addWindow("Processors", processorsWindow(processors))
Shell:addWindow("Locks", activeLocksWindow)
Shell:addWindow("Unlocks", activeUnlocksWindow)
Shell:addWindow("Event Loop", eventLoopWindow)

Shell:run()
