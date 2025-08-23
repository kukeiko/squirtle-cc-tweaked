local InventoryApi = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function(...)
        local shulkers = InventoryApi.getRefreshedByType("shulker")
        local siloOutputs = InventoryApi.getByType("silo:output")
        InventoryApi.restock(siloOutputs, shulkers)
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(storages, shulkers)
    end)

    if not success then
        print(e)
    end
end
