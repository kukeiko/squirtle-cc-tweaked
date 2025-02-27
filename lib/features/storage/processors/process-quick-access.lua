local Inventory = require "lib.apis.inventory-api"

return function()
    local success, e = pcall(function()
        local quickAccesses = Inventory.getRefreshedByType("quick-access")
        local storages = Inventory.getByType("storage")
        Inventory.transfer(storages, "output", quickAccesses, "input")
    end)

    if not success then
        print(e)
    end
end
