local Fuel = require "squirtle.fuel"
local refuelFromBackpack = require "squirtle.refuel.from-backpack"
local refuelWithHelpFromPlayer = require "squirtle.refuel.with-help-from-player"

---@param fuel integer
return function(fuel)
    if Fuel.hasFuel(fuel) then
        return true
    end

    refuelFromBackpack(fuel)

    if Fuel.getFuelLevel() < fuel then
        refuelWithHelpFromPlayer(fuel)
    end
end
