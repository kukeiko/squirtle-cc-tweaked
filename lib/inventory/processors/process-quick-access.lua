local InventoryApi = require "lib.inventory.inventory-api"

return function()
    -- [todo] ❌ causes "event loop thread took 500ms" messages
    local success, e = pcall(function()
        local quickAccesses = InventoryApi.getRefreshedByType("quick-access")
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(storages, quickAccesses)
    end)

    if not success then
        print(e)
    end
end
