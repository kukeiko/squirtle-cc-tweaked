local Inventory = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local trash = Inventory.getRefreshedByType("trash")
        local storages = Inventory.getByType("storage")
        Inventory.empty(trash, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
