local Inventory = require "inventory"

return function()
    local drains = Inventory.getInventories("drain", true)

    local quickAccesses = Inventory.getInventories("quick-access")
    Inventory.distributeFromTag(drains, quickAccesses, "output", "input")

    local io = Inventory.getInventories("io")
    Inventory.distributeFromTag(drains, io, "output", "input")

    local storages = Inventory.getInventories("storage")
    Inventory.distributeFromTag(drains, storages, "output", "input")
end
