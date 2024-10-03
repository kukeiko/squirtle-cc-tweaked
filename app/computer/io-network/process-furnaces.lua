local Utils = require "lib.utils"
local Inventory = require "lib.inventory"

local fuelItems = {"minecraft:lava_bucket", "minecraft:charcoal", "minecraft:coal", "minecraft:coal_block"}

---@param furnaces string[]
---@param item string
---@param maxCount integer
---@return string[]
local function getFurnacesForSmelting(furnaces, item, maxCount)
    local alreadyFilledFurnaces = Utils.filter(furnaces, function(furnace)
        local inputStack = Inventory.getStack(furnace, 1)

        return inputStack ~= nil and inputStack.name == item
    end)

    if #alreadyFilledFurnaces >= maxCount then
        table.sort(alreadyFilledFurnaces)
        return Utils.slice(alreadyFilledFurnaces, 1, maxCount)
    else
        local emptyFurnaces = Utils.filter(furnaces, function(furnace)
            return Inventory.getStack(furnace, 1) == nil
        end)

        return Utils.slice(Utils.concat(alreadyFilledFurnaces, emptyFurnaces), 1, maxCount)
    end
end

return function()
    local success, e = pcall(function()
        local outputs = Inventory.getInventories("furnace-output", true)
        local furnaces = Inventory.getInventories("furnace", true)
        local storages = Inventory.getInventories("storage")
        local siloInputs = Inventory.getInventories("silo:input")
        Inventory.distributeFromTag(furnaces, storages, "output", "input")
        Inventory.distributeFromTag(furnaces, outputs, "output", "input")
        Inventory.distributeFromTag(furnaces, siloInputs, "output", "input")
        Inventory.distributeFromTag(outputs, storages, "output", "input")
        Inventory.distributeFromTag(outputs, siloInputs, "output", "input")
        Inventory.distributeItem(furnaces, storages, "minecraft:bucket", "fuel", "input")

        print("[move] fuel from input")
        local inputs = Inventory.getInventories("furnace-input", true)

        for _, fuelItem in ipairs(fuelItems) do
            Inventory.distributeItem(inputs, furnaces, fuelItem, "output", "fuel")
        end

        local configurations = Inventory.getInventories("furnace-config", true)

        if #configurations > 0 then
            local config = Inventory.getStockByTagMultiInventory(configurations, "configuration")

            print("[move] smelted to output")
            for smeltableItem, maxFurnaces in pairs(config) do
                local targetFurnaces = getFurnacesForSmelting(furnaces, smeltableItem, maxFurnaces)
                print(string.format("[config] %dx %s, %dx available", maxFurnaces, smeltableItem, #targetFurnaces))
                Inventory.distributeItem(inputs, targetFurnaces, smeltableItem, "output", "input")
            end
        else
            print("[info] no furnace configuration found")
        end
    end)

    if not success then
        print(e)
    end
end
