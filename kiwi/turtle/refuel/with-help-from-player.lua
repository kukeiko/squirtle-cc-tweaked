local Utils = require "kiwi.utils"
local refuelFromInventory = require "kiwi.turtle.refuel.from-inventory"

---@param fuel integer
return function(fuel)
    local openFuel = fuel

    while openFuel > 0 do
        print(string.format("[help] not enough fuel, need %d more.", openFuel))
        print("please put some into inventory, then hit enter.")
        Utils.waitForUserToHitEnter()
        openFuel = refuelFromInventory(openFuel)
    end

    return openFuel
end
