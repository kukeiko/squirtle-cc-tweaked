local Fuel = require "kiwi.core.fuel"
local Inventory = require "kiwi.turtle.inventory"

local bucket = "minecraft:bucket"

return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()
    local fuelStacks = Fuel.pickStacks(Inventory.list(), fuel)
    local emptyBucketSlot = Inventory.find(bucket)
    local fuelAtStart = Fuel.getFuelLevel()

    for slot, stack in pairs(fuelStacks) do
        Inventory.selectSlot(slot)
        Fuel.refuel(stack.count)

        local remaining = Inventory.getStack(slot)

        if remaining and remaining.name == bucket then
            if (emptyBucketSlot == nil) or (not Inventory.transfer(emptyBucketSlot)) then
                emptyBucketSlot = slot
            end
        end
    end

    return math.max(0, fuel - (Fuel.getFuelLevel() - fuelAtStart))
end
