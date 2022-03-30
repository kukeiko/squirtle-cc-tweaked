---@class Vector
---@field x number
---@field y number
---@field z number
local Vector = {}

---@return Vector
function Vector.create(x, y, z)
    if type(x) ~= "number" then
        error("expected x to be a number, was " .. type(x))
    elseif type(y) ~= "number" then
        error("expected y to be a number, was " .. type(y))
    elseif type(z) ~= "number" then
        error("expected z to be a number, was " .. type(z))
    end

    local instance = {x = x or 0, y = y or 0, z = z or 0}

    setmetatable(instance, {__tostring = Vector.toString, __concat = Vector.concat})

    return instance
end

function Vector.plus(a, b)
    if (type(a) == "number") then
        return Vector.create(b.x + a, b.y + a, b.z + a)
    elseif (type(b) == "number") then
        return Vector.create(a.x + b, a.y + b, a.z + b)
    else
        return Vector.create(a.x + b.x, a.y + b.y, a.z + b.z)
    end
end

---@param other Vector
function Vector.minus(self, other)
    return Vector.create(self.x - other.x, self.y - other.y, self.z - other.z)
end

---@param self Vector
---@param other Vector
---@return boolean
function Vector.equals(self, other)
    return self.x == other.x and self.y == other.y and self.z == other.z
end

---@param self Vector
---@return number
function Vector.length(self)
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

---@param a Vector
---@param b Vector
---@return number
function Vector.distance(a, b)
    return Vector.length(Vector.minus(a, b))
end

function Vector:negate()
    return Vector.create(-self.x, -self.y, -self.z)
end

function Vector:toString()
    return string.format("%d,%d,%d", self.x, self.y, self.z)
end

function Vector:concat(other)
    return tostring(self) .. tostring(other)
end

---@param a Vector
---@param b Vector
---@return number
function Vector.manhattan(a, b)
    return math.abs(b.x - a.x) + math.abs(b.y - a.y) + math.abs(b.z - a.z)
end

return Vector
