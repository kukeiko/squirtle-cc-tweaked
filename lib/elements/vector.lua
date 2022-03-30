---@class Vector
---@field x number
---@field y number
---@field z number
local Vector = {}

---@return Vector
function Vector.new(x, y, z)
    if type(x) ~= "number" then
        error("expected x to be a number, was " .. type(x))
    elseif type(y) ~= "number" then
        error("expected y to be a number, was " .. type(y))
    elseif type(z) ~= "number" then
        error("expected z to be a number, was " .. type(z))
    end

    local instance = {x = x or 0, y = y or 0, z = z or 0}

    setmetatable(instance, {
        __index = Vector,
        __add = Vector.plus,
        __sub = Vector.minus,
        __mul = Vector.multiply,
        __div = Vector.divide,
        __unm = Vector.negate,
        __mod = Vector.modulo,
        __pow = Vector.power,
        __eq = Vector.equals,
        __tostring = Vector.toString,
        __concat = Vector.concat
    })

    return instance
end

---@return Vector
function Vector.cast(data)
    if type(data) ~= "table" or type(data.x) ~= "number" or type(data.y) ~= "number" or type(data.z) ~= "number" then
        error("not a vector")
    end

    setmetatable(data, {
        __index = Vector,
        __add = Vector.plus,
        __sub = Vector.minus,
        __mul = Vector.multiply,
        __div = Vector.divide,
        __unm = Vector.negate,
        __mod = Vector.modulo,
        __pow = Vector.power,
        __eq = Vector.equals,
        __tostring = Vector.toString,
        __concat = Vector.concat
    })

    return data
end

function Vector.plus(a, b)
    if (type(a) == "number") then
        return Vector.new(b.x + a, b.y + a, b.z + a)
    elseif (type(b) == "number") then
        return Vector.new(a.x + b, a.y + b, a.z + b)
    else
        return Vector.new(a.x + b.x, a.y + b.y, a.z + b.z)
    end
end

-- [todo] not really sure we need to subtract a Vector by a number (that goes for all math ops)
---@param other number|Vector
function Vector.minus(self, other)
    if (type(other) == "number") then
        return Vector.new(self.x - other, self.y - other, self.z - other)
    else
        return Vector.new(self.x - other.x, self.y - other.y, self.z - other.z)
    end
end

function Vector.multiply(a, b)
    if (type(a) == "number") then
        return Vector.new(b.x * a, b.y * a, b.z * a)
    elseif (type(b) == "number") then
        return Vector.new(a.x * b, a.y * b, a.z * b)
    else
        return Vector.new(a.x * b.x, a.y * b.y, a.z * b.z)
    end
end

function Vector.divide(a, b)
    if (type(a) == "number") then
        return Vector.new(b.x / a, b.y / a, b.z / a)
    elseif (type(b) == "number") then
        return Vector.new(a.x / b, a.y / b, a.z / b)
    else
        return Vector.new(a.x / b.x, a.y / b.y, a.z / b.z)
    end
end

function Vector.modulo(self, other)
    if (type(other) == "number") then
        return Vector.new(self.x % other, self.y % other, self.z % other)
    else
        return Vector.new(self.x % other.x, self.y % other.y, self.z % other.z)
    end
end

function Vector.power(a, b)
    if (type(a) == "number") then
        return Vector.new(b.x ^ a, b.y ^ a, b.z ^ a)
    elseif (type(b) == "number") then
        return Vector.new(a.x ^ b, a.y ^ b, a.z ^ b)
    else
        return Vector.new(a.x ^ b.x, a.y ^ b.y, a.z ^ b.z)
    end
end

function Vector:equals(other)
    return self.x == other.x and self.y == other.y and self.z == other.z
end

function Vector:unit()
    local len = self:length()
    return Vector.new(self.x / len, self.y / len, self.z / len)
end

function Vector:unitX()
    return Vector.new(self.x / math.abs(self.x), 0, 0)
end

function Vector:unitY()
    return Vector.new(0, self.y / math.abs(self.y), 0)
end

function Vector:unitZ()
    return Vector.new(0, 0, self.z / math.abs(self.z))
end

function Vector:dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function Vector:cross(other)
    return Vector.new(self.y * other.z - self.z * other.y, self.z * other.x - self.x * other.z,
                      self.x * other.y - self.y * other.x)
end

function Vector:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function Vector:normalize()
    return self:unit()
end

function Vector:distance(other)
    return (other - self):length()
end

function Vector:negate()
    return Vector.new(-self.x, -self.y, -self.z)
end

function Vector:floor()
    return Vector.new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function Vector:asChunkIndex()
    return Vector.new(math.floor(self.x / 16), 0, math.floor(self.z / 16))
end

function Vector:asChunkOrigin()
    local chunkIndex = self:asChunkIndex()

    return Vector.new(chunkIndex.x * 16, self.y, chunkIndex.z * 16)
end

function Vector:toString()
    return string.format("%d,%d,%d", self.x, self.y, self.z)
end

function Vector:concat(other)
    return tostring(self) .. tostring(other)
end

function Vector:rotateLeft(times)
    times = (times or 1) % 4

    if times == 0 then
        return Vector.new(self.x, self.y, self.z)
    elseif times == 1 then
        return Vector.new(self.z, self.y, -self.x)
    elseif times == 2 then
        return Vector.new(-self.x, self.y, -self.z)
    elseif times == 3 then
        return Vector.new(-self.z, self.y, self.x)
    end
end

function Vector:rotateRight(times)
    times = (times or 1) % 4

    if times == 0 then
        return Vector.new(self.x, self.y, self.z)
    elseif times == 1 then
        return Vector.new(-self.z, self.y, self.x)
    elseif times == 2 then
        return Vector.new(-self.x, self.y, -self.z)
    elseif times == 3 then
        return Vector.new(self.z, self.y, -self.x)
    end
end

function Vector:copy()
    return Vector.new(self.x, self.y, self.z)
end

---@param a Vector
---@param b Vector
---@return number
function Vector.manhattan(a, b)
    return math.abs(b.x - a.x) + math.abs(b.y - a.y) + math.abs(b.z - a.z)
end

return Vector
