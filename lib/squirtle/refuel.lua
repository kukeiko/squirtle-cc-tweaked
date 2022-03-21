local Fuel = require "squirtle.fuel"
local refuelFromInventory = require "squirtle.refuel.from-inventory"
local refuelWithHelpFromPlayer = require "squirtle.refuel.with-help-from-player"

---@param fuel integer
return function(fuel)
    if Fuel.hasFuel(fuel) then
        return true
    end

    refuelFromInventory(fuel)

    if Fuel.getFuelLevel() < fuel then
        refuelWithHelpFromPlayer(fuel)
    end
end
