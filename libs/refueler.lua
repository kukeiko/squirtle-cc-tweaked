package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Inventory = require "inventory"
local Squirtle = require "squirtle"
local Turtle = require "turtle"

local Refueler = {}

-- todo: add "maxFuelLevel" & "allowedOverFlow" args, just like @pickFuelSlots
function Refueler.refuelFromInventory()
    local fuelLevelAtStart = turtle.getFuelLevel()
    local remainingSlots = {}
    local firstEmptyBucketSlot = nil

    for slot = 1, Inventory.numSlots() do
        local item = turtle.getItemDetail(slot)

        if item ~= nil and FuelDictionary.isFuel(item.name) then
            local refuelAmount = FuelDictionary.getRefuelAmount(item.name)
            local numItemsToRefuel = math.floor(Turtle.getMissingFuel() / refuelAmount)

            if numItemsToRefuel > 0 then
                turtle.select(slot)
                turtle.refuel(numItemsToRefuel)

                if item.name == "minecraft:lava_bucket" then
                    if not firstEmptyBucketSlot then
                        firstEmptyBucketSlot = slot
                    else
                        turtle.transferTo(firstEmptyBucketSlot)
                    end
                end
            end

            if turtle.getItemCount(slot) > 0 then
                table.insert(remainingSlots, slot)
            end
        end
    end

    return turtle.getFuelLevel() - fuelLevelAtStart, remainingSlots
end

function Refueler.pickFuelSlots(items, maxFuelLevel, allowedOverFlow)
    maxFuelLevel = math.max(maxFuelLevel or 0, 0)
    local missingFuel = maxFuelLevel - turtle.getFuelLevel()

    if missingFuel <= 0 then
        return {}
    end

    local pickedSlots = {}
    allowedOverFlow = math.max(allowedOverFlow or 0, 0)

    for slot, item in pairs(items) do
        if FuelDictionary.isFuel(item.name) then
            local itemRefuelAmount = FuelDictionary.getRefuelAmount(item.name)

            if itemRefuelAmount < missingFuel + allowedOverFlow then
                table.insert(pickedSlots, slot)
                missingFuel = missingFuel - item.count * itemRefuelAmount
            end
        end
    end

    table.sort(pickedSlots)

    return pickedSlots, missingFuel
end

function Refueler.refuelFromBuffer(side, maxFuelLevel, allowedOverFlow)
    -- question - if the buffer is full, are we allowed to temporarily use the turtle inventory?
    local buffer = peripheral.wrap(side)
    local fuelSlots = Refueler.pickFuelSlots(buffer.list(), maxFuelLevel, allowedOverFlow)

    if #fuelSlots == 0 then
        return 0
    end

    if not Squirtle.moveFirstSlotSomewhereElse() then
        error("inventory full")
    end

    turtle.select(1)
    local fuelLevelAtStart = turtle.getFuelLevel()

    for i = 1, #fuelSlots do
        local bufferFuelSlot = fuelSlots[i]
        print("sucking buffer fuel slot: " .. bufferFuelSlot)
        -- [todo] it can happen that we suck in more fuel than expected in case buffer is not compacted
        -- think about how we wanna have the API behave here.
        -- suckSlotFromContainer(bufferSide, bufferFuelSlot)
        Squirtle.suckSlotFromContainer(side, bufferFuelSlot)
        turtle.refuel()

        if turtle.getItemCount(1) > 0 then
            print("dropping remainder")
            Turtle.drop(side)
            -- consolidate empty buckets
            buffer.pushItems(side, 1, nil, 2)
        end
    end

    return turtle.getFuelLevel() - fuelLevelAtStart
end

function Refueler.refuelFromInputUsingBuffer(inputSide, bufferSide, maxFuelLevel, allowedOverflow)
    local input = peripheral.wrap(inputSide)
    local fuelSlots = Refueler.pickFuelSlots(input.list(), maxFuelLevel, allowedOverflow)

    if #fuelSlots == 0 then
        return 0, "no fuel in input"
    end

    local fuelLevelAtStart = turtle.getFuelLevel()
    local buffer = peripheral.wrap(bufferSide)
    local firstEmptyBufferSlot = Squirtle.firstEmptySlotInItems(buffer.list(), buffer.size())

    if not firstEmptyBufferSlot then
        return 0, "buffer full"
    end

    if firstEmptyBufferSlot ~= 1 then
        buffer.pushItems(bufferSide, 1, firstEmptyBufferSlot)
    end

    if not Squirtle.selectFirstEmptySlot() then
        return 0, "inventory full"
    end

    for i = 1, #fuelSlots do
        local fuelSlot = fuelSlots[i]
        input.pushItems(bufferSide, fuelSlot, nil, 1)
        Turtle.suck(bufferSide)
        turtle.refuel()

        -- todo: what if is bucket?
    end

    return turtle.getFuelLevel() - fuelLevelAtStart
end

return Refueler
