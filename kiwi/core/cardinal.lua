local Vector = require "kiwi.core.vector"
local Side = require "kiwi.core.side";

---@class KiwiCardinal
local KiwiCardinal = {
    south = 0,
    west = 1,
    north = 2,
    east = 3,
    up = 4,
    down = 5
    -- vector = {
    --     south = Vector.new(0, 0, 1),
    --     west = Vector.new(-1, 0, 0),
    --     north = Vector.new(0, 0, -1),
    --     east = Vector.new(1, 0, 0)
    -- }
}

-- local names = {}

-- for k, v in pairs(KiwiCardinal) do
--     names[v] = k
-- end

local names = {
    [KiwiCardinal.south] = "south",
    [KiwiCardinal.west] = "west",
    [KiwiCardinal.north] = "north",
    [KiwiCardinal.east] = "east",
    [KiwiCardinal.up] = "up",
    [KiwiCardinal.down] = "down"
}

---@param vector Vector
function KiwiCardinal.fromVector(vector)
    if vector.x > 0 and vector.y == 0 and vector.z == 0 then
        return KiwiCardinal.east
    elseif vector.x < 0 and vector.y == 0 and vector.z == 0 then
        return KiwiCardinal.west
    elseif vector.x == 0 and vector.y == 0 and vector.z > 0 then
        return KiwiCardinal.south
    elseif vector.x == 0 and vector.y == 0 and vector.z < 0 then
        return KiwiCardinal.north
    elseif vector.x == 0 and vector.y > 0 and vector.z == 0 then
        return KiwiCardinal.up
    elseif vector.x == 0 and vector.y < 0 and vector.z == 0 then
        return KiwiCardinal.down
    end

    error(vector .. " is not a cardinal vector")
end

---@param cardinal number
function KiwiCardinal.toVector(cardinal)
    if cardinal == KiwiCardinal.south then
        return Vector.new(0, 0, 1)
    elseif cardinal == KiwiCardinal.west then
        return Vector.new(-1, 0, 0)
    elseif cardinal == KiwiCardinal.north then
        return Vector.new(0, 0, -1)
    elseif cardinal == KiwiCardinal.east then
        return Vector.new(1, 0, 0)
    elseif cardinal == KiwiCardinal.up then
        return Vector.new(0, 1, 0)
    elseif cardinal == KiwiCardinal.down then
        return Vector.new(0, -1, 0)
    end
end

---@param cardinal number
function KiwiCardinal.getName(cardinal)
    local name = names[cardinal]

    if name == nil then
        error("not a valid cardinal: " .. tostring(cardinal))
    end

    return names[cardinal] or tostring(cardinal);
end

-- function KiwiCardinal.rotate(cardinal, rotation)
--     return (cardinal + rotation) % 4
-- end

---@param cardinal integer
---@param times? number
---@return integer
function KiwiCardinal.rotateLeft(cardinal, times)
    return (cardinal - (times or 1)) % 4
end

---@param cardinal integer
---@param times? number
---@return integer
function KiwiCardinal.rotateRight(cardinal, times)
    return (cardinal + (times or 1)) % 4
end

---@param cardinal integer
---@return integer
function KiwiCardinal.rotateAround(cardinal, times)
    return (cardinal + (2 * (times or 1))) % 4
end

function KiwiCardinal.rotate(cardinal, side, times)
    if side == Side.left then
        return KiwiCardinal.rotateLeft(cardinal, times)
    elseif side == Side.right then
        return KiwiCardinal.rotateRight(cardinal, times)
    elseif side == Side.back then
        return KiwiCardinal.rotateAround(cardinal, times)
    elseif side == Side.front then
        return cardinal
    else
        error(string.format("rotate() doesn't support side %s", Side.getName(side)))
    end
end

-- function KiwiCardinal.rotateBy(cardinal, by)
--     if (cardinal + 1) % 4 == by then
--     else if (cardinal - 1) % 4 == by then
--     else
--     end
-- end

function KiwiCardinal.isVertical(cardinal)
    return cardinal == KiwiCardinal.up or cardinal == KiwiCardinal.down
end

function KiwiCardinal.fromSide(side, facing)
    if side == Side.front then
        return facing
    elseif side == Side.top then
        return KiwiCardinal.up
    elseif side == Side.bottom then
        return KiwiCardinal.down
    elseif side == Side.left then
        return KiwiCardinal.rotateLeft(facing)
    elseif side == Side.right then
        return KiwiCardinal.rotateRight(facing)
    elseif side == Side.back then
        return KiwiCardinal.rotateAround(facing)
    end
end

---@param value integer
function KiwiCardinal.isCardinal(value)
    return value >= 0 and value <= 5
end

return KiwiCardinal
