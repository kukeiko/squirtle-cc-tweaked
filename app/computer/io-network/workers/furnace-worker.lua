local Utils = require "utils"
local Inventory = require "inventory.inventory"
local readFurnace = require "io-network.read.read-furnace"
local readFurnaceInputInventory = require "io-network.read.read-furnace-input-inventory"
local readFurnaceOutputInventory = require "io-network.read.read-furnace-output-inventory"
local transferStock = require "io-network.transfer-stock"

-- [note] refuel numbers not actually used
local fuelItems = {"minecraft:lava_bucket", "minecraft:charcoal", "minecraft:coal", "minecraft:coal_block"}
local lavaBucket = "minecraft:lava_bucket"

-- [todo] this furnace worker is currently not using locks for furnaces and furnace input/output,
-- as I could not reuse transferStock() without doing major hacks.
-- [update] figure out why I couldn't use transferStock(). has been a while since I wrote this worker,
-- and I really can't remember what hacks I would have to introduce to make it work.
-- [update#2] I think it is outdated; I might've fixed it by having "allocateNextToStack()" check inventory type.
-- [update#3] akshually, probably not fully correct: furnace fuel input stack is in its "input" inventory.
-- maybe I can have it in both input and output?
---@param collection InventoryCollection
---@param timeout integer
return function(collection, timeout)
    while true do
        local success, e = pcall(function()
            collection:refreshInventories("furnace-input", "furnace-output", "furnace")

            local inputs = collection:getInventories("furnace-input")
            local outputs = collection:getInventories("furnace-output")
            local furnaces = collection:getInventories("furnace")

            print(string.format("[found] %d inputs and %d furnaces", #inputs, #furnaces))

            local inputStock = Inventory.mergeStocks(Utils.map(inputs, function(item)
                return item.output.stock
            end))

            -- take out any empty buckets
            local emptyBucketStorages = Utils.filter(collection:getInventories("storage"), function(storage)
                local stock = storage.input.stock["minecraft:bucket"]

                return stock and stock.count < stock.maxCount
            end)

            for _, furnace in pairs(furnaces) do
                for _, emptyBucketStorage in pairs(emptyBucketStorages) do
                    Inventory.transferItem(furnace.input, emptyBucketStorage.input, "minecraft:bucket")
                end
            end

            -- distributing fuel items evenly across all furnaces
            for _, fuelItem in ipairs(fuelItems) do
                if inputStock[fuelItem] then
                    -- print(string.format("[dbg] transferring %dx %s", inputStock[fuelItem].count, fuelItem))
                    transferStock({[fuelItem] = inputStock[fuelItem]}, inputs, furnaces, collection, true)
                    -- [todo] bit of a hack to make transferStock() later on work
                    inputStock[fuelItem] = nil
                end
            end

            -- move smelted items to "Furnace: Output" chests
            for _, furnace in pairs(furnaces) do
                local outputStack = furnace.output.stacks[3]

                if outputStack then
                    for _, output in pairs(outputs) do
                        Inventory.transferItem(furnace.output, output.input, outputStack.name, nil, nil, true)
                    end
                end
            end

            -- move items to smelt from "Furnace: Input" chest to furnaces
            -- [todo] see if we can't also transfer fuel items this way.
            transferStock(inputStock, inputs, furnaces, collection, true)
            os.sleep(timeout)
        end)

        if not success then
            print(e)
        end
    end
end
