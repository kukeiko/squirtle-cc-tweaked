if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
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
            processDumps()
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

---@return SearchableListOption[]
local function getActiveLockList()
    local options = Utils.map(InventoryLocks.getLockedInventories(), function(inventory)
        ---@type SearchableListOption
        local option = {id = inventory, name = inventory, suffix = InventoryCollection.getType(inventory)}

        return option
    end)

    return options
end

---@param shellWindow ShellWindow
local function activeLocks(shellWindow)
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

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(1.0)
    term.redirect(monitor)
end

term.clear()

EventLoop.run(function()
    RemoteService.run({"storage"})
end, function()
    Rpc.host(StorageService)
end, function()
    local Shell = require "lib.ui.shell"

    Shell:addWindow("Logs", main)
    Shell:addWindow("Locks", activeLocks)
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

    Shell:addWindow("Modem Messages", function()
        while true do
            local event = {EventLoop.pull("modem_message")}
            ---@type integer
            local channel = event[3]
            ---@type integer
            local replyChannel = event[3]
            ---@type RpcResponsePacket|RpcRequestPacket|RpcPingPacket|RpcPongPacket
            local message = event[5]
            ---@type number?
            local distance = event[6]

            if type(message) == "table" then
                print(
                    string.format("[%s] %s %s  %d/%d (%d)", message.type, message.method, message.service, channel, replyChannel, distance))
            end
        end
    end)

    Shell:addWindow("Tasks (cc:tweaked)", function()
        while true do
            local event = {EventLoop.pull("task_complete")}
            print(event[1], event[2], event[3], event[4])
        end
    end)

    Shell:run()
end)
