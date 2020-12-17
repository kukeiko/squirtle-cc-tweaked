package.path = package.path .. ";/libs/?.lua"

local Sides = {}

function Sides.invert(side)
    if side == "left" then
        return "right"
    elseif side == "right" then
        return "left"
    elseif side == "top" then
        return "bottom"
    elseif side == "bottom" then
        return "top"
    elseif side == "front" then
        return "back"
    elseif side == "back" then
        return "front"
    else
        error(side .. " is not a valid side")
    end
end

---@return table
function Sides.all()
    return {"back", "front", "left", "right", "top", "bottom"}
end

function Sides.isHorizontal(side)
    return side == "left" or side == "right" or side == "back"
end

function Sides.isVertical(side)
    return side == "top" or side == "bottom"
end

return Sides

-- local sides = require("sides")

-- sides.turn = {
--     left = {
--         [0] = 0,
--         [1] = 1,
--         [2] = 4,
--         [3] = 5,
--         [4] = 3,
--         [5] = 2,
--         [6] = 6
--     },
--     right = {
--         [0] = 0,
--         [1] = 1,
--         [2] = 5,
--         [3] = 4,
--         [4] = 2,
--         [5] = 3,
--         [6] = 6
--     },
--     around = {
--         [0] = 1,
--         [1] = 0,
--         [2] = 3,
--         [3] = 2,
--         [4] = 5,
--         [5] = 4,
--         [6] = 6
--     }
-- }

-- return sides
