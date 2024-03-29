local Inventory = require "inventory"

return function()
    local success, e = pcall(function(...)
        local shulkers = Inventory.getInventories("shulker", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(storages, shulkers, "output", "input")
    end)

    if not success then
        print(e)
    end
end
