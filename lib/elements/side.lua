---@class Side
local Side = {front = 0, right = 1, back = 2, left = 3, top = 4, bottom = 5, up = 4, down = 5}

local lookup = {
    front = 0,
    [0] = "front",
    right = 1,
    [1] = "right",
    back = 2,
    [2] = "back",
    left = 3,
    [3] = "left",
    top = 4,
    [4] = "top",
    bottom = 5,
    [5] = "bottom",
    forward = 0,
    up = 4,
    down = 5
}

if not turtle then
    Side.right = 3
    Side.left = 1
end

local names = {}

for k, v in pairs(Side) do
    names[v] = k
end

---@param side string|integer
function Side.getName(side)
    if type(side) == "string" then
        return side
    else
        return names[side] or tostring(side);
    end
end

---@param side string
---@return string
function Side.rotateAround(side)
    return lookup[(lookup[side] + 2) % 4]
end

return Side
