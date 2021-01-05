package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = {}
local fuelItems = {
    ["minecraft:lava_bucket"] = 1000,
    ["minecraft:coal"] = 80,
    ["minecraft:bamboo"] = 2
}

--- @param item string
function FuelDictionary.isFuel(item)
    return fuelItems[item] ~= nil
end

--- @param item string
function FuelDictionary.getRefuelAmount(item)
    return fuelItems[item] or 0
end

--- @param stack table
function FuelDictionary.getStackRefuelAmount(stack)
    return FuelDictionary.getRefuelAmount(stack.name) * stack.count
end

return FuelDictionary
