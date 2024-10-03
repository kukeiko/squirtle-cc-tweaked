local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local io = Inventory.getInventories("io", true)
        Inventory.distributeFromTag(io, io, "output", "input")
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(io, storages, "output", "input")
    end)

    if not success then
        print(e)
    end
end
