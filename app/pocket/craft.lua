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
local RemoteService = require "lib.services.remote-service"
local TaskService = require "lib.services.task-service"
local StorageService = require "lib.features.storage.storage-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
function getListOptions(storage)
    local stock = storage.getCraftableStock()
    local itemDetails = storage.getItemDetails()

    local options = Utils.map(stock, function(quantity, item)
        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName or item, suffix = tostring(quantity)}
    end)

    table.sort(options, function(a, b)
        return a.name < b.name
    end)

    return options
end

function getListTitle()
    local commonTitle = "What item would you like crafted?"
    local titles = {"What we craftin' today, lad?", "Me craft gud yes?", commonTitle, commonTitle, commonTitle}

    return titles[math.random(#titles)]
end

EventLoop.run(function()
    RemoteService.run({"craft"})
end, function()
    print(string.format("[craft %s] connecting to storage service...", version()))
    os.sleep(1)

    local storage = Rpc.nearest(StorageService)
    local taskService = Rpc.nearest(TaskService)
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
                    print("[wait] crafting...")
                    -- [todo] I've refactored this to just 1x method call, but now I don't see a way to show the progress to the user :?
                    local task = taskService.craftItems({issuedBy = os.getComputerLabel(), item = item.id, quantity = quantity})

                    taskService.deleteTask(task.id)
                    -- [todo] it should be allowed for the task/storage system to reboot while transferring and everything still works
                    print(string.format("[done] enjoy your %dx %s!", quantity, item.name))
                    os.sleep(1)
                end
            end
        end
    end)
end)
