---@class Side
local Side = {front = 0, right = 1, back = 2, left = 3, top = 4, bottom = 5}

if not turtle then
    Side.right = 3
    Side.left = 1
end

local names = {}

for k, v in pairs(Side) do
    names[v] = k
end

---@return number[]
function Side.all()
    local sides = {}

    for i = 0, 5 do
        table.insert(sides, i)
    end

    return sides
end

function Side.horizontal()
    local sides = {}

    for i = 0, 3 do
        table.insert(sides, i)
    end

    return sides
end

---@param side number
function Side.getName(side)
    return names[side] or tostring(side);
end

---@param str string
function Side.fromString(str)
    local side = Side[str:lower()]

    if side == nil then
        error("invalid Side name: " .. str)
    end

    return side
end

---@param arg string|number
---@return integer
function Side.fromArg(arg)
    local type = type(arg)

    -- [todo] use cc.expect
    if type == "number" then
        if arg >= 0 and arg <= 5 then
            return arg
        else
            error("Side out of range: " .. arg)
        end
    elseif type == "string" then
        return Side.fromString(arg)
    else
        error("unexpected Side arg type: " .. type)
    end
end

---@param side integer
---@param times? number
---@return integer
function Side.rotateLeft(side, times)
    return (side - (times or 1)) % 4
end

---@param side integer
---@param times? number
---@return integer
function Side.rotateRight(side, times)
    return (side + (times or 1)) % 4
end

---@param side integer
---@return integer
function Side.rotateAround(side)
    return (side + 2) % 4
end

return Side
