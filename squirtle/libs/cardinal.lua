local Vector = require "squirtle.libs.vector"
local Side = require "squirtle.libs.side";

local Cardinal = {
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

-- for k, v in pairs(Cardinal) do
--     names[v] = k
-- end

local names = {
    [Cardinal.south] = "south",
    [Cardinal.west] = "west",
    [Cardinal.north] = "north",
    [Cardinal.east] = "east",
    [Cardinal.up] = "up",
    [Cardinal.down] = "down"
}

---@param vector Vector
function Cardinal.fromVector(vector)
    if vector.x == 1 and vector.y == 0 and vector.z == 0 then
        return Cardinal.east
    elseif vector.x == -1 and vector.y == 0 and vector.z == 0 then
        return Cardinal.west
    elseif vector.x == 0 and vector.y == 0 and vector.z == 1 then
        return Cardinal.south
    elseif vector.x == 0 and vector.y == 0 and vector.z == -1 then
        return Cardinal.north
    elseif vector.x == 0 and vector.y == 1 and vector.z == 0 then
        return Cardinal.up
    elseif vector.x == 0 and vector.y == -1 and vector.z == 0 then
        return Cardinal.down
    end

    error(vector .. " is not a cardinal vector")
end

---@param cardinal number
function Cardinal.toVector(cardinal)
    if cardinal == Cardinal.south then
        return Vector.new(0, 0, 1)
    elseif cardinal == Cardinal.west then
        return Vector.new(-1, 0, 0)
    elseif cardinal == Cardinal.north then
        return Vector.new(0, 0, -1)
    elseif cardinal == Cardinal.east then
        return Vector.new(1, 0, 0)
    elseif cardinal == Cardinal.up then
        return Vector.new(0, 1, 0)
    elseif cardinal == Cardinal.down then
        return Vector.new(0, -1, 0)
    end
end

---@param cardinal number
function Cardinal.getName(cardinal)
    local name = names[cardinal]

    if name == nil then
        error("not a valid cardinal: " .. tostring(cardinal))
    end

    return names[cardinal] or tostring(cardinal);
end

-- function Cardinal.rotate(cardinal, rotation)
--     return (cardinal + rotation) % 4
-- end

---@param cardinal integer
---@param times? number
function Cardinal.rotateLeft(cardinal, times)
    return (cardinal - (times or 1)) % 4
end

---@param cardinal integer
---@param times? number
function Cardinal.rotateRight(cardinal, times)
    return (cardinal + (times or 1)) % 4
end

function Cardinal.rotateAround(cardinal)
    return (cardinal + 2) % 4
end

-- function Cardinal.rotateBy(cardinal, by)
--     if (cardinal + 1) % 4 == by then
--     else if (cardinal - 1) % 4 == by then
--     else
--     end
-- end

function Cardinal.isVertical(cardinal)
    return cardinal == Cardinal.up or cardinal == Cardinal.down
end

function Cardinal.fromSide(side, facing)
    if side == Side.front then
        return facing
    elseif side == Side.top then
        return Cardinal.up
    elseif side == Side.bottom then
        return Cardinal.down
    elseif side == Side.left then
        return Cardinal.rotateLeft(facing)
    elseif side == Side.right then
        return Cardinal.rotateRight(facing)
    elseif side == Side.back then
        return Cardinal.rotateAround(facing)
    end
end

return Cardinal
