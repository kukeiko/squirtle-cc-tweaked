---@param inventories InputOutputInventoriesByType
return function(inventories)
    print("found:")
    local numIo = #inventories.io
    local numStorage = #inventories.storage
    local numDrains = #inventories.drain
    local numFurnaces = #inventories.furnace
    local numSilos = #inventories.silo

    if numIo > 0 then
        print(" - " .. numIo .. "x I/O")
    end

    if numStorage > 0 then
        print(" - " .. numStorage .. "x Storage")
    end

    if numDrains > 0 then
        print(" - " .. numDrains .. "x Drain")
    end

    if numFurnaces > 0 then
        print(" - " .. numFurnaces .. "x Furnace")
    end

    if numSilos > 0 then
        print(" - " .. numSilos .. "x Silo")
    end
end
