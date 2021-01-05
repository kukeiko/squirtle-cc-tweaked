if not turtle then
    error("not a turtle")
end

package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"

local Inventory = {}

function Inventory.size()
    return 16
end

function Inventory.sumFuelLevel()
    local fuelSlots = Inventory.getFuelSlots()
    local fuel = 0

    for i = 1, #fuelSlots do
        fuel = fuel + FuelDictionary.getStackRefuelAmount(turtle.getItemDetail(fuelSlots[i]))
    end

    return fuel
end

function Inventory.getFuelSlots()
    local fuelSlots = {}

    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) > 0 and FuelDictionary.isFuel(turtle.getItemDetail(slot).name) then
            table.insert(fuelSlots, slot)
        end
    end

    return fuelSlots
end

function Inventory.getFuelStacks()
    local fuelStacks = {}

    for slot = 1, Inventory.size() do
        local stack = turtle.getItemDetail(slot)

        if stack ~= nil and FuelDictionary.isFuel(stack.name) then
            table.insert(fuelStacks, stack)
        end
    end

    return fuelStacks
end

return Inventory
