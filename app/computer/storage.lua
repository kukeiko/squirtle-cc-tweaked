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
local SearchableList = require "lib.ui.searchable-list"

local processors = {dumps = true, furnaces = true, io = true, quickAccess = true, shulkers = true, trash = true, siloOutputs = true}

local function main()
    print(string.format("[storage %s] booting...", version()))
    Inventory.useCache(true)
    Inventory.discover()
    print("[storage] ready!")
    Utils.writeStartupFile("storage")

    EventLoop.runUntil("storage:stop", function()
        Inventory.start()
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
    end)
end

local function processorList()
    local function getProcessorList()
        return Utils.map(processors, function(isEnabled, processor)
            ---@type SearchableListOption
            local option = {id = processor, name = processor, suffix = isEnabled and "[on]" or ""}

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

---@param shellWindow ShellWindow
local function activeLocks(shellWindow)
    ---@return SearchableListOption[]
    local function getActiveLockList()
        local options = Utils.map(InventoryLocks.getLockedInventories(), function(inventory)
            ---@type SearchableListOption
            local option = {id = inventory, name = inventory, suffix = InventoryCollection.getType(inventory)}

            return option
        end)

        return options
    end

    local list = SearchableList.new(getActiveLockList(), "Active Locks")

    EventLoop.run(function()
        while true do
            list:run()
        end
    end, function()
        while true do
            if shellWindow:isVisible() then
                InventoryLocks.pullLockChange()

                if shellWindow:isVisible() then
                    list:setOptions(getActiveLockList())
                end
            else
                os.sleep(1)
            end
        end
    end)
end

---@param shellWindow ShellWindow
local function activeUnlocks(shellWindow)
    ---@return SearchableListOption[]
    local function getActiveUnlockList()
        local options = Utils.map(InventoryLocks.getInventoriesPendingUnlock(), function(inventory)
            ---@type SearchableListOption
            local option = {id = inventory, name = inventory, suffix = InventoryCollection.getType(inventory)}

            return option
        end)

        return options
    end

    local list = SearchableList.new(getActiveUnlockList(), "Active Unocks")

    EventLoop.run(function()
        while true do
            list:run()
        end
    end, function()
        while true do
            if shellWindow:isVisible() then
                InventoryLocks.pullLockChange()

                if shellWindow:isVisible() then
                    list:setOptions(getActiveUnlockList())
                end
            else
                os.sleep(1)
            end
        end
    end)
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(1.0)
    term.redirect(monitor)
end

term.clear()

local Shell = require "lib.ui.shell"

Shell:addWindow("Logs", main)
Shell:addWindow("Processors", processorList)

Shell:addWindow("RPC", function()
    EventLoop.run(function()
        RemoteService.run({"storage"})
    end, function()
        Rpc.host(StorageService)
    end)
end)

Shell:addWindow("Locks", activeLocks)
Shell:addWindow("Unlocks", activeUnlocks)
Shell:addWindow("Event Loop", function()
    local start = os.epoch("utc")

    ---@return SearchableListOption[]
    local function getStatsList()
        local stats = EventLoop.getPulledEventStats()
        local duration = os.epoch("utc") - start

        local options = Utils.map(stats, function(quantity, event)
            ---@type SearchableListOption
            return {id = event, name = event, suffix = tostring(math.floor(quantity / (duration / 1000)))}
        end)

        start = os.epoch("utc")

        for k in pairs(stats) do
            stats[k] = 0
        end

        return options
    end

    local list = SearchableList.new(getStatsList(), "Pulled Events", nil, 1, getStatsList)
    list:run()
end)

Shell:addWindow("Tasks (cc:tweaked)", function()
    while true do
        local event = {EventLoop.pull("task_complete")}
        print(event[1], event[2], event[3], event[4])
    end
end)

Shell:run()
