local Utils = require "utils"
local Fuel = require "squirtle.fuel"
local refuelFromInventory = require "squirtle.refuel.from-inventory"

---@param fuel? integer
return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()

    while Fuel.getFuelLevel() < fuel do
        local openFuel = fuel - Fuel.getFuelLevel()
        print(string.format("[help] not enough fuel, need %d more.", openFuel))
        print("please put some into inventory, then hit enter.")
        Utils.waitForUserToHitEnter()
        refuelFromInventory(openFuel)
    end
end
