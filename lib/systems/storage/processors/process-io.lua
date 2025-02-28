local InventoryApi = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local io = InventoryApi.getRefreshedByType("io")
        InventoryApi.restock(io, "output", io, "input")
        local storages = InventoryApi.getByType("storage")
        InventoryApi.restock(io, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
