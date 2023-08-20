local Vector = require "elements.vector"

---@class World
---@field width? integer
---@field height? integer
---@field depth? integer
---@field blocked table<string, unknown>
---@field x integer
---@field y integer
---@field z integer
local World = {}

local function swap(a, b)
    return b, a
end

---@param value integer
---@param from integer
---@param length? integer
---@return boolean
local function isInRange(value, from, length)
    if length == nil then
        return true
    elseif length == 0 then
        return false
    end

    local to = from + length

    if to < from then
        from, to = swap(from, to)
    end

    return value >= from and value < to
end

---@param x integer
---@param y integer
---@param z integer
---@param width? integer
---@param height? integer
---@param depth? integer
---@return World
local function create(x, y, z, width, height, depth)
    if (width ~= nil and width < 1) or (height ~= nil and height < 1) or (depth ~= nil and depth < 1) then
        error("can't create world with width/height/depth less than 1")
    end

    ---@type World
    local world = {x = x, y = y, z = z, width = width, height = height, depth = depth, blocked = {}}

    return world
end

---@param world World
---@param x integer
local function isInBoundsX(world, x)
    return isInRange(x, world.x, world.width)
end

---@param world World
---@param y integer
local function isInBoundsY(world, y)
    return isInRange(y, world.y, world.height)
end

---@param world World
---@param z integer
local function isInBoundsZ(world, z)
    return isInRange(z, world.z, world.depth)
end

---@param world World
---@param point Vector
local function isInBounds(world, point)
    return isInBoundsX(world, point.x) and isInBoundsY(world, point.y) and isInBoundsZ(world, point.z)
end

---@param world World
---@param point Vector
local function isInBottomPlane(world, point)
    return point.y == world.y
end

---@param world World
---@param point Vector
local function isInTopPlane(world, point)
    return point.y == world.y + world.height - 1
end

---@param world World
---@param point Vector
---@return boolean
local function isBlocked(world, point)
    if not isInBounds(world, point) then
        return false
    else
        return world.blocked[tostring(point)] ~= nil
    end
end

---@param world World
---@param point Vector
local function setBlock(world, point)
    world.blocked[tostring(point)] = true
end

---@param world World
---@param point Vector
local function clearBlock(world, point)
    world.blocked[tostring(point)] = nil
end

---@param world World
local function getCorners(world)
    return {
        Vector.create(world.x, world.y, world.z),
        Vector.create(world.x + world.width - 1, world.y, world.z),
        Vector.create(world.x, world.y + world.height - 1, world.z),
        Vector.create(world.x + world.width - 1, world.y + world.height - 1, world.z),
        --
        Vector.create(world.x, world.y, world.z + world.depth - 1),
        Vector.create(world.x + world.width - 1, world.y, world.z + world.depth - 1),
        Vector.create(world.x, world.y + world.height - 1, world.z + world.depth - 1),
        Vector.create(world.x + world.width - 1, world.y + world.height - 1, world.z + world.depth - 1)
    }
end

---@param world World
---@param point Vector
local function getClosestCorner(world, point)
    local corners = getCorners(world)

    ---@type Vector
    local best

    for i = 1, #corners do
        if best == nil or Vector.distance(best, point) > Vector.distance(corners[i], point) then
            best = corners[i]
        end
    end

    return best
end

return {
    create = create,
    isInBoundsX = isInBoundsX,
    isInBoundsY = isInBoundsY,
    isInBoundsZ = isInBoundsZ,
    isInBounds = isInBounds,
    isInBottomPlane = isInBottomPlane,
    isInTopPlane = isInTopPlane,
    isBlocked = isBlocked,
    setBlock = setBlock,
    clearBlock = clearBlock,
    getCorners = getCorners,
    getClosestCorner = getClosestCorner
}
