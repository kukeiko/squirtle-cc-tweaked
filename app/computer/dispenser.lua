package.path = package.path .. ";/lib/?.lua"
local Utils = require "utils"
local Rpc = require "rpc"
local EventLoop = require "event-loop"
local StorageService = require "services.storage-service"
local SearchableList = require "ui.searchable-list"
local readInteger = require "ui.read-integer"

EventLoop.run(function()
    print("[dispenser v1.0.0-dev] booting...")

    local storage = Rpc.nearest(StorageService)

    while true do
        local stock = storage.getStock()
        local nonEmptyStock = Utils.filterMap(stock, function(quantity)
            return quantity > 0
        end)

        local options = Utils.map_v2(nonEmptyStock, function(quantity, item)
            ---@type SearchableListOption
            return {id = item, name = item, suffix = tostring(quantity)}
        end)

        table.sort(options, function(a, b)
            return a.id < b.id
        end)

        local commonTitle = "What item would you like transferred?"
        local titles = {"What item ya be needin'?", "I've got the goods!", commonTitle, commonTitle, commonTitle}

        local searchableList = SearchableList.new(options, titles[math.random(#titles)])
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
