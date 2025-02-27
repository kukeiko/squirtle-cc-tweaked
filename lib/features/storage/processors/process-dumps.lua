local Inventory = require "lib.apis.inventory-api"

return function()
    local success, e = pcall(function()
        local dumps = Inventory.getRefreshedByType("dump")

        local quickAccesses = Inventory.getByType("quick-access")
        Inventory.transfer(dumps, "output", quickAccesses, "input")

        local io = Inventory.getByType("io")
        Inventory.transfer(dumps, "output", io, "input")

        local storages = Inventory.getByType("storage")
        Inventory.transfer(dumps, "output", storages, "input")

        local siloInputs = Inventory.getByType("silo:input")
        Inventory.transfer(dumps, "output", siloInputs, "input")

        local composterConfigs = Inventory.getRefreshedByType("composter-config")

        if #composterConfigs > 0 then
            local composterInputs = Inventory.getRefreshedByType("composter-input")
            local configured = Inventory.getStock(composterConfigs, "configuration")

            for compostableItem, _ in pairs(configured) do
                Inventory.transferItem(dumps, "output", composterInputs, "input", compostableItem)
            end
        end

        local trash = Inventory.getRefreshedByType("trash")
        local storedStock = Inventory.getStock(storages, "input")
        local quickAccessStock = Inventory.getStock(quickAccesses, "input")
        -- [todo] should we also include furnace configs?
        local composterConfiguredStock = Inventory.getStock(composterConfigs, "configuration")
        local dumpedStock = Inventory.getStock(dumps, "output")

        for dumpedItem, dumpedCount in pairs(dumpedStock) do
            if not storedStock[dumpedItem] and not composterConfiguredStock[dumpedItem] and not quickAccessStock[dumpedItem] then
                Inventory.transferItem(dumps, "output", trash, "input", dumpedItem, dumpedCount)
            end
        end
    end)

    if not success then
        print(e)
    end
end
