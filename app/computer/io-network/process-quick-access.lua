local Inventory = require "inventory"

return function()
    local quickAccesses = Inventory.getInventories("quick-access", true)
    local storages = Inventory.getInventories("storage")
    Inventory.distributeFromTag(storages, quickAccesses, "output", "input")
end
