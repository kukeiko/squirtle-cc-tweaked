local concatTables = require "utils.concat-tables"
local getInventoriesAcceptingInput = require "io-network.get-inventories-accepting-input"
local transferItem = require "inventory.transfer-item"

---@param chest NetworkedInventory
---@param inventoriesByType NetworkedInventoriesByType
return function(chest, inventoriesByType)
    for item, stock in pairs(chest.output.stock) do
        local ignore = {chest.name}

        -- [todo] the while loop should not be needed anymore afaik
        -- [update] akshually is needed, as we spread items evenly across chests,
        -- and one of them might fill up, but another one might still take it. 
        -- i think.
        while stock.count > 0 do
            local ioChests = getInventoriesAcceptingInput(inventoriesByType.io, ignore, stock.name)

            ---@type NetworkedInventory[]
            local storageChests = {}

            if chest.type ~= "silo" then
                storageChests = getInventoriesAcceptingInput(inventoriesByType.storage, ignore, stock.name)
            end

            local furnaces = getInventoriesAcceptingInput(inventoriesByType.furnace, ignore, stock.name)

            ---@type NetworkedInventory[]
            local inputChests = concatTables(ioChests, furnaces, storageChests)

            if #inputChests == 0 then
                break
            end

            print("[" .. chest.name .. "]")
            print(stock.count .. "x", item, "across:")

            if #ioChests > 0 then
                print(" - ", #ioChests .. "x io chests")
            end

            if #storageChests > 0 then
                print(" - ", #storageChests .. "x storage chests")
            end

            if #furnaces > 0 then
                print(" - ", #furnaces .. "x furnaces")
            end

            local stockPerChest = math.floor(stock.count / #inputChests)
            local rest = stock.count - stockPerChest

            for i, inputChest in ipairs(inputChests) do
                local transfer = stockPerChest

                if i <= rest then
                    transfer = transfer + 1
                end

                local transferred = transferItem(chest.output, inputChest.input, item, transfer, 8)

                if transferred < transfer then
                    -- assuming chest is full or its state changed from an external source, in which case we just ignore it
                    table.insert(ignore, inputChest.name)
                end
            end
        end
    end
end