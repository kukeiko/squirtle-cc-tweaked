local Fuel = require "squirtle.fuel"
local refuelFromBackpack = require "squirtle.refuel.from-backpack"

---@param fuel? integer
return function(fuel)
    fuel = fuel or Fuel.getMissingFuel()

    if fuel > turtle.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - turtle.getFuelLimit()))
    end

    local _, y = term.getCursorPos()

    while Fuel.getFuelLevel() < fuel do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - Fuel.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end
