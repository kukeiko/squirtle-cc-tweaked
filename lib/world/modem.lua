local Peripheral = require "world.peripheral"

local Modem = {}

---@param modem string|integer
function Modem.getNamesRemote(modem)
    return Peripheral.call(modem, "getNamesRemote")
end

---@param modem string|integer
---@param name string
---@return string[]
function Modem.getTypeRemote(modem, name)
    local types = Peripheral.call(modem, "getTypeRemote", name)

    --  cc:tweaked < 1.99
    if type(types) == "string" then
        types = {types}
    end

    return types
end

return Modem
