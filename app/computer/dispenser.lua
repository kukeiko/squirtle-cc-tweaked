package.path = package.path .. ";/lib/?.lua"
local Utils = require "utils"
local Rpc = require "rpc"
local EventLoop = require "event-loop"
local StorageService = require "services.storage-service"
local SearchableList = require "ui.searchable-list"
local readInteger = require "ui.read-integer"

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
function getListOptions(storage)
    local stock = storage.getStock()
    local itemDisplayNames = storage.getItemDisplayNames()
    local nonEmptyStock = Utils.filterMap(stock, function(quantity)
        return quantity > 0
    end)

    local options = Utils.map_v2(nonEmptyStock, function(quantity, item)
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
    print("[dispenser v1.2.1] connecting to storage service...")

    local storage = Rpc.nearest(StorageService)

    while not storage do
        os.sleep(0.25)
        storage = Rpc.nearest(StorageService)
    end

    local rebootAfter = 30
    local refreshStockEvery = 3
    local shutOffTimer = os.startTimer(rebootAfter)
    local userInteractionEvents = {char = true, key = true}
    local options = getListOptions(storage)
    local title = getListTitle()
    local searchableList = SearchableList.new(options, title)

    EventLoop.run(function()
        while true do
            local event = EventLoop.pull()

            if userInteractionEvents[event] then
                shutOffTimer = os.startTimer(rebootAfter)
            end
        end
    end, function()
        while true do
            local _, pulledTimerId = EventLoop.pull("timer")

            if pulledTimerId == shutOffTimer then
                os.shutdown()
            end
        end
    end, function()
        while true do
            os.sleep(refreshStockEvery)
            searchableList:setOptions(getListOptions(storage))
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
                    storage.transferItemToStash(os.getComputerLabel(), item.id, quantity)
                    print("Done!")
                    os.sleep(1)
                end
            end
        end
    end)
end)
