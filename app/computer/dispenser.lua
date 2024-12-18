if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local RemoteService = require "lib.common.remote-service"
local TaskService = require "lib.common.task-service"
local StorageService = require "lib.features.storage.storage-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
function getListOptions(storage)
    local stock = storage.getStock()
    local itemDisplayNames = storage.getItemDisplayNames()
    local nonEmptyStock = Utils.filterMap(stock, function(quantity)
        return quantity > 0
    end)

    local options = Utils.map(nonEmptyStock, function(quantity, item)
        ---@type SearchableListOption
        return {id = item, name = itemDisplayNames[item] or item, suffix = tostring(quantity)}
    end)

    table.sort(options, function(a, b)
        return a.name < b.name
    end)

    return options
end

function getListTitle()
    local commonTitle = "What item would you like transferred?"
    local titles = {"What item ya be needin'?", "I've got the goods!", commonTitle, commonTitle, commonTitle}

    return titles[math.random(#titles)]
end

EventLoop.run(function()
    RemoteService.run({"dispenser"})
end, function()
    print(string.format("[dispenser %s] connecting to storage service...", version()))
    os.sleep(1)

    local storage = Rpc.nearest(StorageService)
    local taskService = Rpc.nearest(TaskService)
    local stashName = storage.getStashName(os.getComputerLabel())
    local idleTimeout = 30
    local refreshInterval = 3
    local userInteractionEvents = {char = true, key = true}
    local options = getListOptions(storage)
    local title = getListTitle()
    local searchableList = SearchableList.new(options, title)

    EventLoop.run(function()
        local idleTimer = os.startTimer(idleTimeout)
        local refreshTimer = os.startTimer(refreshInterval)

        while true do
            local event, timerId = EventLoop.pull()

            if event == "timer" and timerId == idleTimer then
                idleTimer = Utils.restartTimer(idleTimer, idleTimeout)
                refreshTimer = os.cancelTimer(refreshTimer)
            elseif event == "timer" and timerId == refreshTimer then
                searchableList:setOptions(getListOptions(storage))
                refreshTimer = Utils.restartTimer(refreshTimer, refreshInterval)
            elseif userInteractionEvents[event] then
                idleTimer = Utils.restartTimer(idleTimer, idleTimeout)

                if not refreshTimer then
                    refreshTimer = os.startTimer(refreshInterval)
                end
            end
        end
    end, function()
        while true do
            local item = searchableList:run()

            if item then
                print("How many?")
                local quantity = readInteger()

                if quantity and quantity > 0 then
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("Transferring...")
                    local task = taskService.issueTransferItemsTask(os.getComputerLabel(), {stashName}, "input", {[item.id] = quantity})
                    print("Issued task, waiting for completion")
                    -- [todo] it should be allowed for the task/storage system to reboot while transferring and everything still works
                    taskService.awaitTransferItemsTaskCompletion(task)
                    print("Done!")
                    os.sleep(1)
                end
            end
        end
    end)
end)
