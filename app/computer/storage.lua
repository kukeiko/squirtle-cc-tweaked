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
local InventoryLocks = require "lib.apis.inventory.inventory-locks"
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
local SearchableList = require "lib.ui.searchable-list"

local logsWindow = require "lib.systems.shell.windows.logs-window"
local eventLoopWindow = require "lib.systems.shell.windows.event-loop-window"
local activeLocksWindow = require "lib.systems.storage.windows.active-locks-window"
local activeUnlocksWindow = require "lib.systems.storage.windows.active-unlocks-window"

local processors = {dumps = true, furnaces = true, io = true, quickAccess = true, shulkers = true, trash = true, siloOutputs = true}

local function main()
    print(string.format("[storage %s] booting...", version()))
    InventoryPeripheral.addAdapter(TurtleInventoryAdapter)
    Inventory.useCache(true)
    Inventory.discover()
    print("[storage] ready!")
    Utils.writeStartupFile("storage")

    EventLoop.runUntil("storage:stop", function()
        Inventory.start(arg[1])
    end, function()
        while true do
            if processors.dumps then
                processDumps()
            end

            os.sleep(3)
        end
    end, function()
        while true do
            if processors.furnaces then
                processFurnaces()
            end

            os.sleep(30)
        end
    end, function()
        while true do
            if processors.io then
                processIo()
            end

            os.sleep(3)
        end
    end, function()
        while true do
            if processors.quickAccess then
                processQuickAccess()
            end

            os.sleep(10)
        end
    end, function()
        while true do
            if processors.shulkers then
                processShulkers()
            end

            os.sleep(3)
        end
    end, function()
        while true do
            if processors.trash then
                processTrash()
            end

            os.sleep(30)
        end
    end, function()
        while true do
            if processors.siloOutputs then
                processSiloOutputs()
            end

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
    end)
end

local function processorList()
    local function getProcessorList()
        return Utils.map(processors, function(isEnabled, processor)
            ---@type SearchableListOption
            local option = {id = processor, name = processor, suffix = isEnabled and "\07" or ""}

            return option
        end)
    end

    local list = SearchableList.new(getProcessorList(), "Processors")

    while true do
        local selected = list:run()

        if selected then
            processors[selected.id] = not processors[selected.id]
            list:setOptions(getProcessorList())
        end
    end
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

Shell:addWindow("Processors", processorList)
Shell:addWindow("Locks", activeLocksWindow)
Shell:addWindow("Unlocks", activeUnlocksWindow)
Shell:addWindow("Event Loop", eventLoopWindow)

Shell:run()
