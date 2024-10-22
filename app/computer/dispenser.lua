package.path = package.path .. ";/?.lua"

local version = require "version"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local StorageService = require "lib.features.storage.storage-service"
local QuestService = require "lib.common.quest-service"
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

---@param rebootAfter integer
---@param userInteractionEvents table<string, true>
---@param preventAutoReboot function
local function autoReboot(rebootAfter, userInteractionEvents, preventAutoReboot)
    local timer = os.startTimer(rebootAfter)

    while true do
        local event, timerId = EventLoop.pull()

        if event == "timer" and timerId == timer then
            if preventAutoReboot() then
                os.cancelTimer(timer)
                timer = os.startTimer(rebootAfter)
            else
                os.shutdown()
            end
        elseif userInteractionEvents[event] then
            os.cancelTimer(timer)
            timer = os.startTimer(rebootAfter)
        end
    end
end

---@param searchableList SearchableList
---@param storageService StorageService|RpcClient
---@param refreshInterval number
local function refreshOptions(searchableList, storageService, refreshInterval)
    while true do
        os.sleep(refreshInterval)
        searchableList:setOptions(getListOptions(storageService))
    end
end

EventLoop.run(function()
    print(string.format("[dispenser %s] connecting to storage service...", version()))
    os.sleep(1)
    
    local storage = Rpc.nearest(StorageService)

    while not storage do
        os.sleep(0.25)
        storage = Rpc.nearest(StorageService)
    end

    local questService = Rpc.nearest(QuestService)

    if not questService then
        error("could not connect to quest service")
    end

    local stashName = storage.getStashName(os.getComputerLabel())
    local autoRebootTimeout = 30
    local refreshOptionsInterval = 3
    local userInteractionEvents = {char = true, key = true}

    local options = getListOptions(storage)
    local title = getListTitle()
    local searchableList = SearchableList.new(options, title)
    local isTransferring = false

    local function preventAutoReboot()
        return isTransferring
    end

    EventLoop.run(function()
        autoReboot(autoRebootTimeout, userInteractionEvents, preventAutoReboot)
    end, function()
        refreshOptions(searchableList, storage, refreshOptionsInterval)
    end, function()
        while true do
            local item = searchableList:run()

            if item then
                isTransferring = true
                print("How many?")
                local quantity = readInteger()

                if quantity and quantity > 0 then
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("Transferring...")
                    local quest = questService.issueTransferItemsQuest(os.getComputerLabel(), {stashName}, "input", {[item.id] = quantity})
                    print("Issued quest, waiting for completion")
                    -- [todo] it should be allowed for the quest/storage system to reboot while transferring and everything still works
                    questService.awaitTransferItemsQuestCompletion(quest)
                    print("Done!")
                    os.sleep(1)
                end

                isTransferring = false
            end
        end
    end)
end)
