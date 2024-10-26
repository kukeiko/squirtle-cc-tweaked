local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local siloOutputs = Inventory.getRefreshedByType("silo:output")
        local storages = Inventory.getByType("storage")
        Inventory.transfer(siloOutputs, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
