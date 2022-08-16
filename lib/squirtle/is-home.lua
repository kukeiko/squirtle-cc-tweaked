local Side = require "elements.side"
local inspect = require "squirtle.inspect"

---@return boolean
return function()
    local inspected = inspect(Side.bottom)

    return inspected and inspected.name == "minecraft:barrel"
end
