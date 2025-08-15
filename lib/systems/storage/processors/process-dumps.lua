local InventoryApi = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local dumps = InventoryApi.getRefreshedByType("dump")

        local quickAccesses = InventoryApi.getByType("quick-access")
        InventoryApi.empty(dumps, quickAccesses)

        local io = InventoryApi.getByType("io")
        InventoryApi.empty(dumps, io)

        local storages = InventoryApi.getByType("storage")
        InventoryApi.empty(dumps, storages)

        local siloInputs = InventoryApi.getByType("silo:input")
        InventoryApi.empty(dumps, siloInputs)

        local composterConfigs = InventoryApi.getRefreshedByType("composter-config")

        if #composterConfigs > 0 then
            local composterInputs = InventoryApi.getRefreshedByType("composter-input")
            local configured = InventoryApi.getStock(composterConfigs, "configuration")

            for compostableItem in pairs(configured) do
                InventoryApi.transferItem(dumps, composterInputs, compostableItem)
            end
        end

        local trash = InventoryApi.getRefreshedByType("trash")
        local storedStock = InventoryApi.getStock(storages, "input")
        local quickAccessStock = InventoryApi.getStock(quickAccesses, "input")
        -- [todo] should we also include furnace configs?
        local composterConfiguredStock = InventoryApi.getStock(composterConfigs, "configuration")
        local dumpedStock = InventoryApi.getStock(dumps, "output")

        for dumpedItem, dumpedCount in pairs(dumpedStock) do
            if not storedStock[dumpedItem] and not composterConfiguredStock[dumpedItem] and not quickAccessStock[dumpedItem] then
                InventoryApi.transferItem(dumps, trash, dumpedItem, dumpedCount)
            end
        end
    end)

    if not success then
        print(e)
    end
end
