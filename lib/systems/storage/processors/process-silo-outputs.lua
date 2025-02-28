local InventoryApi = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local siloOutputs = InventoryApi.getRefreshedByType("silo:output")
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(siloOutputs, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
