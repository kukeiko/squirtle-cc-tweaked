---@class KiwiWorld
---@field body KiwiBody
---@field width? integer
---@field height? integer
---@field depth? integer
---@field data table
local KiwiWorld = {}

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

---@param body KiwiBody
---@param width? integer
---@param depth? integer
---@param height? integer
---@param data? table
---@return KiwiWorld
function KiwiWorld.new(body, width, height, depth, data)
    ---@type World
    local instance = {body = body, width = width, height = height, depth = depth, data = data or {}}

    setmetatable(instance, {__index = KiwiWorld})

    return instance
end

---@param x integer
function KiwiWorld:isInBoundsX(x)
    return isInRange(x, self.body.position.x, self.width)
end

---@param y integer
function KiwiWorld:isInBoundsY(y)
    return isInRange(y, self.body.position.y, self.height)
end

---@param z integer
function KiwiWorld:isInBoundsZ(z)
    return isInRange(z, self.body.position.z, self.depth)
end

---@param point KiwiVector
function KiwiWorld:isInBounds(point)
    return self:isInBoundsX(point.x) and self:isInBoundsY(point.y) and self:isInBoundsZ(point.z)
end

---@param point KiwiVector
---@return boolean
function KiwiWorld:isBlocked(point)
    if not self:isInBounds(point) then
        return nil
    else
        return self.data[tostring(point)] ~= nil
    end
end

---@param point KiwiVector
function KiwiWorld:setBlock(point)
    self.data[tostring(point)] = true
end

---@param point KiwiVector
function KiwiWorld:clearBlock(point)
    self.data[tostring(point)] = nil
end

return KiwiWorld
