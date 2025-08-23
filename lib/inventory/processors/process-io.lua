local InventoryApi = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local io = InventoryApi.getRefreshedByType("io")
        InventoryApi.restock(io, io)
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(io, storages)

        local composterConfigs = InventoryApi.getRefreshedByType("composter-config")

        if #composterConfigs > 0 then
            local composterInputs = InventoryApi.getRefreshedByType("composter-input")
            local configured = InventoryApi.getStock(composterConfigs, "configuration")

            for compostableItem in pairs(configured) do
                InventoryApi.transferItem(io, composterInputs, compostableItem)
            end
        end
    end)

    if not success then
        print(e)
    end
end
