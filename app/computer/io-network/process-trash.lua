local Inventory = require "inventory"

return function()
    pcall(function()
        local trash = Inventory.getInventories("trash", true)
        local storages = Inventory.getInventories("storage")
        Inventory.distributeFromTag(trash, storages, "output", "input")
    end)
end
