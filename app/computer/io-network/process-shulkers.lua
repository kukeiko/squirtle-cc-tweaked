local Inventory = require "inventory"

return function()
    pcall(function(...)
        local shulkers = Inventory.getInventories("shulker", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(storages, shulkers, "output", "input")
    end)
end
