local Utils = require "utils"
local toInputOutputInventory = require "io-network.to-input-output-inventory"
local transferStock = require "io-network.transfer-stock"

---@param stocks ItemStock[]
---@return ItemStock
local function mergeStocks(stocks)
    ---@type ItemStock
    local merged = {}

    for _, stock in pairs(stocks) do
        for item, itemStock in pairs(stock) do
            local mergedStock = merged[item]

            if not mergedStock then
                merged[item] = Utils.copy(itemStock)
            else
                mergedStock.count = mergedStock.count + itemStock.count
                mergedStock.maxCount = mergedStock.maxCount + itemStock.maxCount
            end
        end
    end

    return merged
end

---@param collection InventoryCollection
---@param type InputOutputInventoryType
---@param timeout integer
return function(collection, type, timeout)
    while true do
        local success, e = pcall(function()
            local outputs = collection:getInventories(type)
            ---@type InputOutputInventory[]
            local refreshed = {}

            for _, output in pairs(outputs) do
                local refreshedOutput = toInputOutputInventory(output.name)

                if refreshedOutput and refreshedOutput.type == type then
                    table.insert(refreshed, refreshedOutput)
                    collection:remove(refreshedOutput.name)
                    collection:add(refreshedOutput)
                else
                    print("[debug] type changed")
                    os.queueEvent("peripheral_detach", output.name)
                    os.queueEvent("peripheral", output.name)
                end
            end

            local outputStocks = Utils.map(refreshed, function(item)
                return item.output.stock
            end)

            local outputStock = mergeStocks(outputStocks)
            transferStock(outputStock, refreshed, collection:getInventories(), collection)

            os.sleep(timeout)
        end)

        if not success then
            print(e)
        end
    end
end
