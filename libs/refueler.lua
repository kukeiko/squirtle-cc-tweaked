package.path = package.path .. ";/libs/?.lua"

local FuelDictionary = require "fuel-dictionary"
local Squirtle = require "squirtle"
local Refueler = {}

function Refueler.refuelFromInventory()
    local fuelLevelAtStart = turtle.getFuelLevel()
    local remainingSlots = {}
    local firstEmptyBucketSlot = nil

    for slot = 1, Squirtle.numSlots() do
        local item = turtle.getItemDetail(slot)

        if item ~= nil and FuelDictionary.isFuel(item.name) then
            local refuelAmount = FuelDictionary.getRefuelAmount(item.name)
            local numItemsToRefuel = math.floor(Squirtle.getMissingFuel() / refuelAmount)

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

return Refueler
