package.path = package.path .. ";/libs/?.lua"

local Sides = {}
-- local numeric = {front = 0, right = 1, back = 2, left = 3}

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

function Sides.horizontal()
    return {"front", "back", "left", "right"}
end

function Sides.isHorizontal(side)
    return side == "left" or side == "right" or side == "back" or side == "front"
end

function Sides.isVertical(side)
    return side == "top" or side == "bottom"
end

function Sides.turnLeft(side)
    if side == "left" then
        return "back"
    elseif side == "right" then
        return "front"
    elseif side == "top" then
        return "top"
    elseif side == "bottom" then
        return "bottom"
    elseif side == "front" then
        return "left"
    elseif side == "back" then
        return "right"
    else
        error(side .. " is not a valid side")
    end
end

function Sides.turnRight(side)
    if side == "left" then
        return "front"
    elseif side == "right" then
        return "back"
    elseif side == "top" then
        return "top"
    elseif side == "bottom" then
        return "bottom"
    elseif side == "front" then
        return "right"
    elseif side == "back" then
        return "left"
    else
        error(side .. " is not a valid side")
    end
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
