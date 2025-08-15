local InventoryApi = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local quickAccesses = InventoryApi.getRefreshedByType("quick-access")
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(storages, quickAccesses)
    end)

    if not success then
        print(e)
    end
end
