package.path = package.path .. ";/libs/?.lua"

local Utils = require "utils"

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

function FuelDictionary.filterStacks(stacks)
    local fuelStacks = {}

    for slot, stack in pairs(stacks) do
        if FuelDictionary.isFuel(stack.name) then
            fuelStacks[slot] = stack
        end
    end

    if Utils.isEmpty(fuelStacks) then
        return nil
    end

    return fuelStacks
end

function FuelDictionary.pickStacks(stacks, fuelLevel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 0, 0)
    local pickedStacks = {}
    local openFuel = fuelLevel

    for slot, stack in pairs(stacks) do
        if FuelDictionary.isFuel(stack.name) then
            local stackRefuelAmount = FuelDictionary.getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                local itemRefuelAmount = FuelDictionary.getRefuelAmount(stack.name)
                local numRequiredItems = math.ceil(openFuel / itemRefuelAmount)

                if (numRequiredItems * itemRefuelAmount) - openFuel <= allowedOverFlow then
                    pickedStacks[slot] = {name = stack.name, count = numRequiredItems}
                    openFuel = openFuel - stackRefuelAmount
                end
            end

            if openFuel <= 0 then
                break
            end
        end
    end

    if Utils.isEmpty(pickedStacks) then
        pickedStacks = nil
    end

    return pickedStacks, openFuel
end

return FuelDictionary
