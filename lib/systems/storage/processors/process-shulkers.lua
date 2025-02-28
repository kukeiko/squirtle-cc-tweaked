local InventoryApi = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function(...)
        local shulkers = InventoryApi.getRefreshedByType("shulker")
        local siloOutputs = InventoryApi.getByType("silo:output")
        InventoryApi.restock(siloOutputs, "output", shulkers, "input")
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(storages, "output", shulkers, "input")
    end)

    if not success then
        print(e)
    end
end
