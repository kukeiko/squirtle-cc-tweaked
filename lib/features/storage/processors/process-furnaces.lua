local Utils = require "lib.common.utils"
local Inventory = require "lib.inventory.inventory-api"
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
        local outputs = Inventory.getRefreshedByType("furnace-output")
        local furnaces = Inventory.getRefreshedByType("furnace")
        local storages = Inventory.getByType("storage")
        local siloInputs = Inventory.getByType("silo:input")
        Inventory.transfer(furnaces, "output", storages, "input")
        Inventory.transfer(furnaces, "output", outputs, "input")
        Inventory.transfer(furnaces, "output", siloInputs, "input")
        Inventory.transfer(outputs, "output", storages, "input")
        Inventory.transfer(outputs, "output", siloInputs, "input")
        Inventory.transferItem(furnaces, "fuel", storages, "input", "minecraft:bucket")

        print("[move] fuel from input")
        local inputs = Inventory.getRefreshedByType("furnace-input")

        for _, fuelItem in ipairs(fuelItems) do
            Inventory.transferItem(inputs, "output", furnaces, "fuel", fuelItem)
        end

        local configurations = Inventory.getRefreshedByType("furnace-config")

        if #configurations > 0 then
            local config = Inventory.getStock(configurations, "configuration")

            print("[move] smelted to output")
            for smeltableItem, maxFurnaces in pairs(config) do
                local targetFurnaces = getFurnacesForSmelting(furnaces, smeltableItem, maxFurnaces)
                print(string.format("[config] %dx %s, %dx available", maxFurnaces, smeltableItem, #targetFurnaces))
                Inventory.transferItem(inputs, "output", targetFurnaces, "input", smeltableItem)
            end
        else
            print("[info] no furnace configuration found")
        end
    end)

    if not success then
        print(e)
    end
end
