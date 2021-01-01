package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = {}
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:bamboo"] = 2}

function FuelDictionary.isFuel(name)
    return fuelItems[name] ~= nil
end

function FuelDictionary.getRefuelAmount(name)
    return fuelItems[name] or 0
end

return FuelDictionary
