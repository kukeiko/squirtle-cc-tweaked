---@class KiwiVector
---@field x number
---@field y number
---@field z number
local KiwiVector = {}

---@return KiwiVector
function KiwiVector.new(x, y, z)
    if type(x) ~= "number" then
        error("expected x to be a number, was " .. type(x))
    elseif type(y) ~= "number" then
        error("expected y to be a number, was " .. type(y))
    elseif type(z) ~= "number" then
        error("expected z to be a number, was " .. type(z))
    end

    local instance = {x = x or 0, y = y or 0, z = z or 0}

    setmetatable(instance, {
        __index = KiwiVector,
        __add = KiwiVector.plus,
        __sub = KiwiVector.minus,
        __mul = KiwiVector.multiply,
        __div = KiwiVector.divide,
        __unm = KiwiVector.negate,
        __mod = KiwiVector.modulo,
        __pow = KiwiVector.power,
        __eq = KiwiVector.equals,
        __tostring = KiwiVector.toString,
        __concat = KiwiVector.concat
    })

    return instance
end

---@return KiwiVector
function KiwiVector.cast(data)
    if type(data) ~= "table" or type(data.x) ~= "number" or type(data.y) ~= "number" or type(data.z) ~=
        "number" then
        error("not a vector")
    end

    setmetatable(data, {
        __index = KiwiVector,
        __add = KiwiVector.plus,
        __sub = KiwiVector.minus,
        __mul = KiwiVector.multiply,
        __div = KiwiVector.divide,
        __unm = KiwiVector.negate,
        __mod = KiwiVector.modulo,
        __pow = KiwiVector.power,
        __eq = KiwiVector.equals,
        __tostring = KiwiVector.toString,
        __concat = KiwiVector.concat
    })

    return data
end

function KiwiVector.plus(a, b)
    if (type(a) == "number") then
        return KiwiVector.new(b.x + a, b.y + a, b.z + a)
    elseif (type(b) == "number") then
        return KiwiVector.new(a.x + b, a.y + b, a.z + b)
    else
        return KiwiVector.new(a.x + b.x, a.y + b.y, a.z + b.z)
    end
end

-- [todo] not really sure we need to subtract a KiwiVector by a number (that goes for all math ops)
---@param other number|KiwiVector
function KiwiVector.minus(self, other)
    if (type(other) == "number") then
        return KiwiVector.new(self.x - other, self.y - other, self.z - other)
    else
        return KiwiVector.new(self.x - other.x, self.y - other.y, self.z - other.z)
    end
end

function KiwiVector.multiply(a, b)
    if (type(a) == "number") then
        return KiwiVector.new(b.x * a, b.y * a, b.z * a)
    elseif (type(b) == "number") then
        return KiwiVector.new(a.x * b, a.y * b, a.z * b)
    else
        return KiwiVector.new(a.x * b.x, a.y * b.y, a.z * b.z)
    end
end

function KiwiVector.divide(a, b)
    if (type(a) == "number") then
        return KiwiVector.new(b.x / a, b.y / a, b.z / a)
    elseif (type(b) == "number") then
        return KiwiVector.new(a.x / b, a.y / b, a.z / b)
    else
        return KiwiVector.new(a.x / b.x, a.y / b.y, a.z / b.z)
    end
end

function KiwiVector.modulo(self, other)
    if (type(other) == "number") then
        return KiwiVector.new(self.x % other, self.y % other, self.z % other)
    else
        return KiwiVector.new(self.x % other.x, self.y % other.y, self.z % other.z)
    end
end

function KiwiVector.power(a, b)
    if (type(a) == "number") then
        return KiwiVector.new(b.x ^ a, b.y ^ a, b.z ^ a)
    elseif (type(b) == "number") then
        return KiwiVector.new(a.x ^ b, a.y ^ b, a.z ^ b)
    else
        return KiwiVector.new(a.x ^ b.x, a.y ^ b.y, a.z ^ b.z)
    end
end

function KiwiVector:equals(other)
    return self.x == other.x and self.y == other.y and self.z == other.z
end

function KiwiVector:unit()
    local len = self:length()
    return KiwiVector.new(self.x / len, self.y / len, self.z / len)
end

function KiwiVector:unitX()
    return KiwiVector.new(self.x / math.abs(self.x), 0, 0)
end

function KiwiVector:unitY()
    return KiwiVector.new(0, self.y / math.abs(self.y), 0)
end

function KiwiVector:unitZ()
    return KiwiVector.new(0, 0, self.z / math.abs(self.z))
end

function KiwiVector:dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function KiwiVector:cross(other)
    return KiwiVector.new(self.y * other.z - self.z * other.y, self.z * other.x - self.x * other.z,
                          self.x * other.y - self.y * other.x)
end

function KiwiVector:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function KiwiVector:normalize()
    return self:unit()
end

function KiwiVector:distance(other)
    return (other - self):length()
end

function KiwiVector:negate()
    return KiwiVector.new(-self.x, -self.y, -self.z)
end

function KiwiVector:floor()
    return KiwiVector.new(math.floor(self.x), math.floor(self.y), math.floor(self.z))
end

function KiwiVector:asChunkIndex()
    return KiwiVector.new(math.floor(self.x / 16), 0, math.floor(self.z / 16))
end

function KiwiVector:asChunkOrigin()
    local chunkIndex = self:asChunkIndex()

    return KiwiVector.new(chunkIndex.x * 16, self.y, chunkIndex.z * 16)
end

function KiwiVector:toString()
    return string.format("%d,%d,%d", self.x, self.y, self.z)
end

function KiwiVector:concat(other)
    return tostring(self) .. tostring(other)
end

function KiwiVector:rotateLeft(times)
    times = (times or 1) % 4

    if times == 0 then
        return KiwiVector.new(self.x, self.y, self.z)
    elseif times == 1 then
        return KiwiVector.new(self.z, self.y, -self.x)
    elseif times == 2 then
        return KiwiVector.new(-self.x, self.y, -self.z)
    elseif times == 3 then
        return KiwiVector.new(-self.z, self.y, self.x)
    end
end

function KiwiVector:rotateRight(times)
    times = (times or 1) % 4

    if times == 0 then
        return KiwiVector.new(self.x, self.y, self.z)
    elseif times == 1 then
        return KiwiVector.new(-self.z, self.y, self.x)
    elseif times == 2 then
        return KiwiVector.new(-self.x, self.y, -self.z)
    elseif times == 3 then
        return KiwiVector.new(self.z, self.y, -self.x)
    end
end

function KiwiVector:copy()
    return KiwiVector.new(self.x, self.y, self.z)
end

return KiwiVector
