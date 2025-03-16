if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local EventLoop = require "lib.tools.event-loop"
local RemoteService = require "lib.systems.runtime.remote-service"
local StorageService = require "lib.systems.storage.storage-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
function getListOptions(storage)
    local stock = storage.getStock()
    local itemDetails = storage.getItemDetails()
    local nonEmptyStock = Utils.filterMap(stock, function(quantity)
        return quantity > 0
    end)

    local options = Utils.map(nonEmptyStock, function(quantity, item)
        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = tostring(quantity)}
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
    local stash = os.getComputerLabel()
    local idleTimeout = 5
    local refreshInterval = 3
    local options = getListOptions(storage)
    local title = getListTitle()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getListOptions(storage)
    end)

    EventLoop.run(function()
        while true do
            local item = searchableList:run()

            if item then
                print(string.format("How many %s?", item.name))
                local quantity = readInteger()

                if quantity and quantity > 0 then
                    term.clear()
                    term.setCursorPos(1, 1)
                    print("[wait] transferring...")
                    local storages = storage.getByType("storage")
                    -- [todo] I've refactored this to just 1x method call, but now I don't see a way to show the progress to the user :?
                    storage.transfer(storages, stash, {[item.id] = quantity})
                    print(string.format("[done] enjoy your %dx %s!", quantity, item.name))
                    os.sleep(1)
                end
            end
        end
    end)
end)
