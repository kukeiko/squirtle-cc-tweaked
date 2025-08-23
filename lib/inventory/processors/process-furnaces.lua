local Utils = require "lib.tools.utils"
local InventoryApi = require "lib.inventory.inventory-api"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"

local fuelItems = {"minecraft:lava_bucket", "minecraft:charcoal", "minecraft:coal", "minecraft:coal_block"}

---@param furnaces string[]
---@param item string
---@param maxCount integer
---@return string[]
local function getFurnacesForSmelting(furnaces, item, maxCount)
    local alreadyFilledFurnaces = Utils.filter(furnaces, function(furnace)
        local inputStack = InventoryPeripheral.getStack(furnace, 1)

        return inputStack ~= nil and inputStack.name == item
    end)

    if #alreadyFilledFurnaces >= maxCount then
        table.sort(alreadyFilledFurnaces)
        return Utils.slice(alreadyFilledFurnaces, 1, maxCount)
    else
        local emptyFurnaces = Utils.filter(furnaces, function(furnace)
            return InventoryPeripheral.getStack(furnace, 1) == nil
        end)

        return Utils.slice(Utils.concat(alreadyFilledFurnaces, emptyFurnaces), 1, maxCount)
    end
end

return function()
    local success, e = pcall(function()
        local outputs = InventoryApi.getRefreshedByType("furnace-output")
        local furnaces = InventoryApi.getRefreshedByType("furnace")
        local storages = InventoryApi.getByType("storage")
        local siloInputs = InventoryApi.getByType("silo:input")
        -- [todo] ❌ I'm pretty sure we can combine the next 3x .empty() calls by using the "toSequential = true" option,
        -- and also the same with the 2x .empty() calls after
        InventoryApi.empty(furnaces, storages)
        InventoryApi.empty(furnaces, outputs)
        InventoryApi.empty(furnaces, siloInputs)
        InventoryApi.empty(outputs, storages)
        InventoryApi.empty(outputs, siloInputs)
        InventoryApi.transferItem(furnaces, storages, "minecraft:bucket", nil, {fromTag = "fuel"})

        print("[move] fuel from input")
        local inputs = InventoryApi.getRefreshedByType("furnace-input")

        for _, fuelItem in ipairs(fuelItems) do
            InventoryApi.transferItem(inputs, furnaces, fuelItem, nil, {toTag = "fuel"})
        end

        local configurations = InventoryApi.getRefreshedByType("furnace-config")

        if #configurations > 0 then
            local config = InventoryApi.getStock(configurations, "configuration")

            print("[move] smelted to output")
            for smeltableItem, maxFurnaces in pairs(config) do
                local targetFurnaces = getFurnacesForSmelting(furnaces, smeltableItem, maxFurnaces)
                print(string.format("[config] %dx %s, %dx available", maxFurnaces, smeltableItem, #targetFurnaces))
                InventoryApi.transferItem(inputs, targetFurnaces, smeltableItem)
            end
        else
            print("[info] no furnace configuration found")
        end
    end)

    if not success then
        print(e)
    end
end
