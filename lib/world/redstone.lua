local Side = require "elements.side"
local Redstone = {}

---@param side string|integer
---@param flag boolean
function Redstone.setOutput(side, flag)
    if type(side) == "number" then
        side = Side.getName(side)
    end

    return redstone.setOutput(side, flag)
end

---@param side string|integer|string[]|integer[]
---@return boolean
function Redstone.getInput(side)
    if type(side) == "number" then
        side = {Side.getName(side)}
    elseif type(side) == "string" then
        side = {side}
    elseif type(side) == "table" then
        local sides = {}

        for i = 1, #side do
            if type(side[i]) == "string" then
                sides[i] = side[i]
            elseif type(side[i]) == "number" then
                sides[i] = Side.getName(side[i])
            end
        end

        side = sides
    end

    for i = 1, #side do
        if redstone.getInput(side[i]) then
            return Side.fromArg(side[i])
        end
    end
end

return Redstone
