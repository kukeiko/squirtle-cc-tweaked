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

---@param side string|integer
---@return boolean
function Redstone.getInput(side)
    if type(side) == "number" then
        side = Side.getName(side)
    end

    return redstone.getInput(side)
end

return Redstone
