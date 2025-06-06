local Utils = require "lib.tools.utils"
local Side = require "lib.apis.side"

local Peripheral = {}

---@param types string[]|string
---@param sides? string[]
---@return string?, string?
function Peripheral.findSide(types, sides)
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

return Peripheral
