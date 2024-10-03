local Redstone = {}

---@param side string|string[]
---@return string?
function Redstone.getInput(side)
    if type(side) == "string" then
        side = {side}
    end

    for i = 1, #side do
        if redstone.getInput(side[i]) then
            return side[i]
        end
    end
end

return Redstone
