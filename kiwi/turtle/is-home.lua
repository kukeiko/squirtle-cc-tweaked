local Side = require "kiwi.core.side"
local inspect = require "kiwi.turtle.inspect"

---@return boolean
return function()
    local inspected = inspect(Side.bottom)

    return inspected and inspected.name == "minecraft:barrel"
end
