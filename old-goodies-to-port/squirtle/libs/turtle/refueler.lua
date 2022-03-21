local Turtle = require "squirtle.libs.turtle"
local Inventory = require "squirtle.libs.turtle.inventory"
local FuelItems = require "squirtle.libs.fuel-items"
local Utils = require "squirtle.libs.utils"
local Refueler = {}

function Refueler.refuelWithHelpFromPlayer(fuel)
    local openFuel = fuel

    while openFuel > 0 do
        print("[help] not enough fuel, need " .. openFuel ..
                  " more. put some into inventory, then hit enter.")
        Utils.waitForUserToHitEnter()
        openFuel = Refueler.refuelFromInventory(openFuel)
    end
end

---@param fuel? integer
---@param overflow? integer
---@return number openFuel
function Refueler.refuelFromInventory(fuel, overflow)
    fuel = fuel or Turtle.getMissingFuel()
    local fuelStacks = FuelItems.pickStacks(Inventory.list(), fuel, overflow)

    if Utils.isEmpty(fuelStacks) then
        return fuel
    end

    local emptyBucketSlot = Inventory.find("minecraft:bucket")
    local fuelAtStart = Turtle.getFuelLevel()

    for slot, stack in pairs(fuelStacks) do
        Turtle.select(slot)
        Turtle.refuel(stack.count)

        local remaining = Turtle.getItemDetail(slot)

        if remaining and remaining.name == "minecraft:bucket" then
            if emptyBucketSlot == nil then
                emptyBucketSlot = slot
            elseif not Turtle.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end

    return math.max(0, fuel - (Turtle.getFuelLevel() - fuelAtStart))
end

return Refueler
