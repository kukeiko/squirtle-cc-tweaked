local Inventory = require "lib.apis.inventory.inventory-api"

return function()
    local success, e = pcall(function()
        local io = Inventory.getRefreshedByType("io")
        Inventory.transfer(io, "output", io, "input")
        local storages = Inventory.getByType("storage")
        Inventory.transfer(io, "output", storages, "input")
    end)

    if not success then
        print(e)
    end
end
