local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local trash = Inventory.getInventories("trash", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(trash, storages, "output", "input")
    end)

    if not success then
        print(e)
    end
end
