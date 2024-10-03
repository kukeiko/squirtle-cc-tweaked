local Inventory = require "lib.inventory"

return function()
    local success, e = pcall(function()
        local siloOutputs = Inventory.getInventories("silo:output", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(siloOutputs, storages, "output", "input")
    end)

    if not success then
        print(e)
    end
end
