local Inventory = require "lib.apis.inventory-api"

return function()
    local success, e = pcall(function(...)
        local shulkers = Inventory.getRefreshedByType("shulker")
        local siloOutputs = Inventory.getByType("silo:output")
        Inventory.transfer(siloOutputs, "output", shulkers, "input")
        local storages = Inventory.getByType("storage")
        Inventory.transfer(storages, "output", shulkers, "input")
    end)

    if not success then
        print(e)
    end
end
