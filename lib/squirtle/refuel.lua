local Fuel = require "kiwi.core.fuel"
local refuelFromInventory = require "kiwi.turtle.refuel.from-inventory"
local refuelWithHelpFromPlayer = require "kiwi.turtle.refuel.with-help-from-player"

---@param fuel integer
return function(fuel)
    if Fuel.hasFuel(fuel) then
        return true
    end

    fuel = refuelFromInventory(fuel)

    if fuel == 0 then
        return true
    end

    fuel = refuelWithHelpFromPlayer(fuel)

    if fuel == 0 then
        return true
    end

    error("could not acquire enough fuel")
end
