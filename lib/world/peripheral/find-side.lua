local Side = require "elements.side"

---@param types string[]|string
---@param sides? string[]
---@return integer, string
return function(types, sides)
    if type(types) == "string" then
        types = {types}
    end

    sides = sides or Side.allNames()

    for i = 1, #sides do
        local foundType = peripheral.getType(sides[i])

        if foundType ~= nil then
            for e = 1, #types do
                if foundType == types[e] then
                    return sides[i], types[e]
                end
            end
        end
    end
end
