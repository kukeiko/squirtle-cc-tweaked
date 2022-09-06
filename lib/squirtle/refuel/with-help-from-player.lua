local Fuel = require "squirtle.fuel"
local refuelFromBackpack = require "squirtle.refuel.from-backpack"

---@param fuel? integer
return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()

    while Fuel.getFuelLevel() < fuel do
        local openFuel = fuel - Fuel.getFuelLevel()
        print(string.format("[help] not enough fuel, need %d more.", openFuel))
        print("please put some into inventory")
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end
