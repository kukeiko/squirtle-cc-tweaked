local Utils = require "lib.tools.utils"
local Side = require "lib.common.side"

local PeripheralApi = {}

---@param types string[]|string
---@param sides? string[]
---@return string?, string?
function PeripheralApi.findSide(types, sides)
    if type(types) == "string" then
        types = {types}
    end

    sides = sides or Side.allNames()

    for i = 1, #sides do
        local foundTypes = {peripheral.getType(sides[i])}

        if foundTypes ~= nil then
            for e = 1, #types do
                if Utils.indexOf(foundTypes, types[e]) then
                    return sides[i], types[e]
                end
            end
        end
    end
end

---@return string?
function PeripheralApi.findWiredModem()
    local wiredModem = peripheral.find("modem", function(_, modem)
        return not modem.isWireless()
    end)

    return wiredModem and peripheral.getName(wiredModem) or nil
end

---@return string?
function PeripheralApi.findWirelessModem()
    local wirelessModem = peripheral.find("modem", function(_, modem)
        return modem.isWireless()
    end)

    return wirelessModem and peripheral.getName(wirelessModem) or nil
end

return PeripheralApi
