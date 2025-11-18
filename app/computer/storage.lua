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
local TaskWorkerPool = require "lib.system.task-worker-pool"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory-api"
local InventoryCollection = require "lib.inventory.inventory-collection"
local StorageService = require "lib.inventory.storage-service"
local RemoteService = require "lib.system.remote-service"
local processDumps = require "lib.inventory.processors.process-dumps"
local processFurnaces = require "lib.inventory.processors.process-furnaces"
local processIo = require "lib.inventory.processors.process-io"
local processQuickAccess = require "lib.inventory.processors.process-quick-access"
local processShulkers = require "lib.inventory.processors.process-shulkers"
local processTrash = require "lib.inventory.processors.process-trash"
local processSiloOutputs = require "lib.inventory.processors.process-silo-outputs"
local TurtleInventoryAdapter = require "lib.turtle.turtle-inventory-adapter"
local logsWindow = require "lib.system.windows.logs-window"
local eventLoopWindow = require "lib.system.windows.event-loop-window"
local activeLocksWindow = require "lib.inventory.windows.active-locks-window"
local activeUnlocksWindow = require "lib.inventory.windows.active-unlocks-window"
local processorsWindow = require "lib.inventory.windows.processors-window"
local CraftItemsTaskWorker = require "lib.inventory.workers.craft-items-worker"
local AllocateIngredientsTaskWorker = require "lib.inventory.workers.allocate-ingredients-worker"
local ProvideItemsTaskWorker = require "lib.inventory.workers.provide-items-worker"

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

local numWorkersPerTaskType = 2

local function main()
    print(string.format("[storage %s] booting...", version()))
    print(string.format("[storage] using %dx workers for each task", numWorkersPerTaskType))
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

local function workers()
    -- give system a bit of time until localhost StorageService is available
    os.sleep(1)

    EventLoop.run(function()
        TaskWorkerPool.new(AllocateIngredientsTaskWorker, numWorkersPerTaskType):run()
    end, function()
        TaskWorkerPool.new(CraftItemsTaskWorker, numWorkersPerTaskType):run()
    end, function()
        TaskWorkerPool.new(ProvideItemsTaskWorker, numWorkersPerTaskType):run()
    end)
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(1.0)
    term.redirect(monitor)
end

term.clear()

local Shell = require "lib.system.shell"

Shell:addWindow("Main", main)
Shell:addWindow("Workers", workers)
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
