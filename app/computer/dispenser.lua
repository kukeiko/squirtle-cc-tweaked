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
local TaskService = require "lib.systems.task.task-service"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"

---@param storage StorageService|RpcClient
---@return SearchableListOption[]
function getListOptions(storage)
    local stock = storage.getStock()
    local craftableStock = storage.getCraftableStock()
    local itemDetails = storage.getItemDetails()

    local nonEmptyStock = Utils.filterMap(stock, function(quantity, item)
        return quantity > 0 or (craftableStock[item] or 0) > 0
    end)

    local options = Utils.map(nonEmptyStock, function(quantity, item)
        local suffix = tostring(quantity + (craftableStock[item] or 0))

        ---@type SearchableListOption
        return {id = item, name = itemDetails[item].displayName, suffix = suffix}
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

    local storageService = Rpc.nearest(StorageService)
    local taskService = Rpc.nearest(TaskService)
    local stash = os.getComputerLabel()
    local idleTimeout = 5
    local refreshInterval = 3
    local options = getListOptions(storageService)
    local title = getListTitle()
    local searchableList = SearchableList.new(options, title, idleTimeout, refreshInterval, function()
        return getListOptions(storageService)
    end)

    EventLoop.run(function()
        while true do
            local selection = searchableList:run()

            if selection then
                local available = storageService.getItemCount(selection.id)
                local craftable = storageService.getCraftableCount(selection.id)
                local total = available
                print(string.format("How many %s?", selection.name))
                print(string.format(" - Stored: %d", available))

                if craftable and craftable > 0 then
                    total = available + craftable
                    print(string.format(" - Craftable: %d", craftable))
                    print(string.format(" - Total: %d", total))
                end

                local quantity = readInteger(nil, {max = total})

                if quantity and quantity > 0 then
                    quantity = math.min(total, quantity)
                    term.clear()
                    term.setCursorPos(1, 1)

                    if quantity > available then
                        print("[wait] crafting & transferring...")
                    else
                        print("[wait] transferring...")
                    end

                    -- [todo] I've refactored this to just 1x method call, but now I don't see a way to show the progress to the user :?
                    local task = taskService.provideItems({
                        issuedBy = os.getComputerLabel(),
                        craftMissing = true,
                        items = {[selection.id] = quantity},
                        to = stash
                    })

                    taskService.deleteTask(task.id)
                    print(string.format("[done] enjoy your %dx %s!", quantity, selection.name))
                    os.sleep(1)
                end
            end
        end
    end)
end)
