local Fuel = require "squirtle.fuel"
local Inventory = require "squirtle.inventory"

local bucket = "minecraft:bucket"

---@param fuel? integer
return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()
    local fuelStacks = Fuel.pickStacks(Inventory.list(), fuel)
    local emptyBucketSlot = Inventory.find(bucket)

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
end
