if not turtle then
    error("not a turtle")
end

package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Turtle = require "turtle"

local Inventory = {}

function Inventory.size()
    return 16
end

function Inventory.availableSize()
    local numEmpty = 0

    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

function Inventory.isEmpty()
    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

function Inventory.isFull()
    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

function Inventory.firstEmptySlot()
    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

function Inventory.selectFirstEmptySlot()
    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    turtle.select(slot)

    return slot
end

function Inventory.selectFirstOccupiedSlot()
    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            return slot
        end
    end

    return false
end

-- [todo] unsure about how we deal with various data types for items (name only, stack, name-map => stack, slot-map => stack, ...)
function Inventory.find(name)
    for slot = 1, Inventory.size() do
        local item = turtle.getItemDetail(slot)

        if item and item.name == name then
            return slot
        end
    end
end

function Inventory.select(name)
    local slot = Inventory.find(name)

    if not slot then
        return false
    end

    turtle.select(slot)

    return slot
end

function Inventory.moveFirstSlotSomewhereElse()
    if turtle.getItemCount(1) == 0 then
        return true
    end

    turtle.select(1)

    local slot = Inventory.firstEmptySlot()

    if not slot then
        return false
    end

    turtle.transferTo(slot)
end

function Inventory.dumpTo(outputSide)
    for slot = 1, Inventory.size() do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            Turtle.drop(outputSide)
        end
    end

    return Inventory.isEmpty()
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
