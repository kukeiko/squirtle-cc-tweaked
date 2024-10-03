local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local quickAccesses = Inventory.getInventories("quick-access", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(storages, quickAccesses, "output", "input")
    end)

    if not success then
        print(e)
    end
end
