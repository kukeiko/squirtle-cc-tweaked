local Inventory = require "inventory"

return function()
    local success, e = pcall(function()
        local drains = Inventory.getInventories("drain", true)

        local quickAccesses = Inventory.getInventories("quick-access")
        Inventory.distributeFromTag(drains, quickAccesses, "output", "input")

        local io = Inventory.getInventories("io")
        Inventory.distributeFromTag(drains, io, "output", "input")

        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(drains, storages, "output", "input")

        local siloInputs = Inventory.getInventories("silo:input")
        Inventory.distributeFromTag(drains, siloInputs, "output", "input")

        local composterConfigs = Inventory.getInventories("composter-config", true)

        if #composterConfigs > 0 then
            local composterInputs = Inventory.getInventories("composter-input", true)
            local configured = Inventory.getStockByTagMultiInventory(composterConfigs, "configuration")

            for compostableItem, _ in pairs(configured) do
                Inventory.distributeItem(drains, composterInputs, compostableItem, "output", "input")
            end
        end

        local trash = Inventory.getInventories("trash", true)
        local storedStock = Inventory.getStockByTagMultiInventory(storages, "input")
        local quickAccessStock = Inventory.getStockByTagMultiInventory(quickAccesses, "input")
        -- [todo] should we also include furnace configs?
        local composterConfiguredStock = Inventory.getStockByTagMultiInventory(composterConfigs, "configuration")
        local dumpedStock = Inventory.getStockByTagMultiInventory(drains, "output")

        for dumpedItem, dumpedCount in pairs(dumpedStock) do
            if not storedStock[dumpedItem] and not composterConfiguredStock[dumpedItem] and not quickAccessStock[dumpedItem] then
                Inventory.distributeItem(drains, trash, dumpedItem, "output", "input", dumpedCount)
            end
        end
    end)

    if not success then
        print(e)
    end
end
