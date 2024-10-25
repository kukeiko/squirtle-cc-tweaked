local Inventory = require "lib.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local io = Inventory.getByType("io", true)
        Inventory.transfer(io, "output", io, "input")
        local storages = Inventory.getByType("storage")
        Inventory.transfer(io, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
