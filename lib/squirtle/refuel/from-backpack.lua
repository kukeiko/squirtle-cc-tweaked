local Fuel = require "squirtle.fuel"
local Backpack = require "squirtle.backpack"

local bucket = "minecraft:bucket"

---@param fuel? integer
return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()
    local fuelStacks = Fuel.pickStacks(Backpack.getStacks(), fuel)
    local emptyBucketSlot = Backpack.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        Backpack.selectSlot(slot)
        Fuel.refuel(stack.count)

        local remaining = Backpack.getStack(slot)

        if remaining and remaining.name == bucket then
            if (emptyBucketSlot == nil) or (not Backpack.transfer(emptyBucketSlot)) then
                emptyBucketSlot = slot
            end
        end
    end
end
