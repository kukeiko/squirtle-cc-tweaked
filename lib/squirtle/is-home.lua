local inspect = require "squirtle.inspect"

---@return boolean
return function()
    local inspected = inspect("bottom")

    return inspected ~= nil and inspected.name == "minecraft:barrel"
end
