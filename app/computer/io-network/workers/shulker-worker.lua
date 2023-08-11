local transferStock = require "io-network.transfer-stock"
local EventLoop = require "event-loop"
local Utils = require "utils"

---@param name string
local function waitUntilDetached(name)
    while true do
        local _, detachedName = EventLoop.pull("peripheral_detach")

        if detachedName == name then
            break
        end
    end
end

---@param collection InventoryCollection
---@param inventory InputOutputInventory
return function(collection, inventory)
    parallel.waitForAny(function()
        ---@type ItemStock
        local missingStock = {}

        for item, stock in pairs(inventory.input.stock) do
            missingStock[item] = Utils.copy(stock)
            missingStock[item].count = stock.maxCount - stock.count
        end

        print(missingStock["minecraft:comparator"])
        transferStock(missingStock, collection:getInventories("storage"), {inventory}, collection)
    end, function()
        waitUntilDetached(inventory.name)
    end)
end
