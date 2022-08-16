local indexOf = require "utils.index-of"
local allSideNames = require "elements.side.all-names"

---@param types string[]|string
---@param sides? string[]
---@return string, string
return function(types, sides)
    if type(types) == "string" then
        types = {types}
    end

    sides = sides or allSideNames()

    for i = 1, #sides do
        local foundTypes = {peripheral.getType(sides[i])}

        if foundTypes ~= nil then
            for e = 1, #types do
                if indexOf(foundTypes, types[e]) > 0 then
                    return sides[i], types[e]
                end
            end
        end
    end
end
