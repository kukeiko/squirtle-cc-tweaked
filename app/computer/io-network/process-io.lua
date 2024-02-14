local Inventory = require "inventory"

return function()
    local io = Inventory.getInventories("io", true)
    Inventory.distributeFromTag(io, io, "output", "input")
    local storages = Inventory.getInventories("storage")
    Inventory.distributeFromTag(io, storages, "output", "input")
end
