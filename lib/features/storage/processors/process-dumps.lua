local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local dumps = Inventory.getInventories("dump", true)

        local quickAccesses = Inventory.getInventories("quick-access")
        Inventory.distributeFromTag(dumps, quickAccesses, "output", "input")

        local io = Inventory.getInventories("io")
        Inventory.distributeFromTag(dumps, io, "output", "input")

        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(dumps, storages, "output", "input")

        local siloInputs = Inventory.getInventories("silo:input")
        Inventory.distributeFromTag(dumps, siloInputs, "output", "input")

        local composterConfigs = Inventory.getInventories("composter-config", true)

        if #composterConfigs > 0 then
            local composterInputs = Inventory.getInventories("composter-input", true)
            local configured = Inventory.getStockByTagMultiInventory(composterConfigs, "configuration")

            for compostableItem, _ in pairs(configured) do
                Inventory.distributeItem(dumps, composterInputs, compostableItem, "output", "input")
            end
        end

        local trash = Inventory.getInventories("trash", true)
        local storedStock = Inventory.getStockByTagMultiInventory(storages, "input")
        local quickAccessStock = Inventory.getStockByTagMultiInventory(quickAccesses, "input")
        -- [todo] should we also include furnace configs?
        local composterConfiguredStock = Inventory.getStockByTagMultiInventory(composterConfigs, "configuration")
        local dumpedStock = Inventory.getStockByTagMultiInventory(dumps, "output")

        for dumpedItem, dumpedCount in pairs(dumpedStock) do
            if not storedStock[dumpedItem] and not composterConfiguredStock[dumpedItem] and not quickAccessStock[dumpedItem] then
                Inventory.distributeItem(dumps, trash, dumpedItem, "output", "input", dumpedCount)
            end
        end
    end)

    if not success then
        print(e)
    end
end
