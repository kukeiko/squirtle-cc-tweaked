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
local EditEntity = require "lib.ui.edit-entity"
local TaskWorkerPool = require "lib.system.task-worker-pool"
local PeripheralApi = require "lib.common.peripheral-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory.inventory-api"
local InventoryCollection = require "lib.inventory.inventory-collection"
local StorageService = require "lib.inventory.storage-service"
local processDumps = require "lib.inventory.processors.process-dumps"
local processFurnaces = require "lib.inventory.processors.process-furnaces"
local processIo = require "lib.inventory.processors.process-io"
local processQuickAccess = require "lib.inventory.processors.process-quick-access"
local processShulkers = require "lib.inventory.processors.process-shulkers"
local processTrash = require "lib.inventory.processors.process-trash"
local processSiloOutputs = require "lib.inventory.processors.process-silo-outputs"
local TurtleInventoryAdapter = require "lib.turtle.turtle-inventory-adapter"
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
local Shell = require "lib.system.shell"
local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    ---@class StorageAppOptions
    ---@field isAutoStorage boolean?
    ---@field powerChest string?

    local editEntity = EditEntity.new("Storage Options", ".kita/data/storage.options.json")
    editEntity:addString("powerChest", "Power Chest", {values = {"top", "front", "bottom", "back"}, optional = true})
    editEntity:addBoolean("isAutoStorage", "Auto Storage")

    ---@type StorageAppOptions
    local options = editEntity:run({}, app:wasAutorun())
    local monitor = peripheral.find("monitor")

    if monitor then
        print("[redirected to monitor]")
        monitor.setTextScale(1.0)
        EventLoop.configure({window = monitor})
    end

    print(string.format("[storage %s] booting...", version()))
    print(string.format("[storage] using %dx workers for each task", numWorkersPerTaskType))
    InventoryPeripheral.addAdapter(TurtleInventoryAdapter)
    Inventory.useCache(true)
    Inventory.useAutoStorage(options.isAutoStorage)
    Inventory.discover()
    print("[storage] ready!")

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

    EventLoop.run(function()
        Inventory.start(options.powerChest)
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
end)

app:addWindow("Workers", function()
    -- give system a bit of time until localhost StorageService is available & power items are read
    -- [todo] ❌ use events instead
    os.sleep(3)

    EventLoop.run(function()
        TaskWorkerPool.new(AllocateIngredientsTaskWorker, numWorkersPerTaskType):run()
    end, function()
        TaskWorkerPool.new(CraftItemsTaskWorker, numWorkersPerTaskType):run()
    end, function()
        TaskWorkerPool.new(ProvideItemsTaskWorker, numWorkersPerTaskType):run()
    end)
end)

app:addLogsWindow()

app:addWindow("RPC", function()
    EventLoop.run(function()
        Rpc.host(StorageService)
    end, function()
        if PeripheralApi.findWiredModem() then
            Rpc.host(StorageService, "wired")
        end
    end)
end)

app:addWindow("Processors", processorsWindow(processors))
app:addWindow("Locks", activeLocksWindow)
app:addWindow("Unlocks", activeUnlocksWindow)
app:addWindow("Event Loop", eventLoopWindow)
app:run()
