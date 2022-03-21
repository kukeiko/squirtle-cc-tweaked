---@class World
---@field transform Transform
---@field width? integer
---@field height? integer
---@field depth? integer
---@field data table
local World = {}

local function swap(a, b)
    return b, a
end

---@param value integer
---@param from integer
---@param length integer
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

---@param transform Transform
---@param width? integer
---@param depth? integer
---@param height? integer
---@param data? table
---@return World
function World.new(transform, width, height, depth, data)
    -- [todo] we have a transform, but we're never using its facing. a bit confusing
    ---@type World
    local instance = {transform = transform, width = width, height = height, depth = depth, data = data or {}}

    setmetatable(instance, {__index = World})

    return instance
end

---@param x integer
function World:isInBoundsX(x)
    return isInRange(x, self.transform.position.x, self.width)
end

---@param y integer
function World:isInBoundsY(y)
    return isInRange(y, self.transform.position.y, self.height)
end

---@param z integer
function World:isInBoundsZ(z)
    return isInRange(z, self.transform.position.z, self.depth)
end

---@param point Vector
function World:isInBounds(point)
    return self:isInBoundsX(point.x) and self:isInBoundsY(point.y) and self:isInBoundsZ(point.z)
end

---@param point Vector
---@return boolean
function World:isBlocked(point)
    if not self:isInBounds(point) then
        return nil
    else
        return self.data[tostring(point)] ~= nil
    end
end

---@param point Vector
function World:setBlock(point)
    self.data[tostring(point)] = true
end

---@param point Vector
function World:clearBlock(point)
    self.data[tostring(point)] = nil
end

return World
