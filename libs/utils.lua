package.path = package.path .. ";/libs/?.lua"

local Pretty = require "cc.pretty"

local Utils = {}

function Utils.concat(a, b)
    for i = 1, #b do
        a[#a + 1] = b[i]
    end

    return a
end

-- https://stackoverflow.com/a/26367080/1611592
function Utils.copy(obj, seen)
    if type(obj) ~= 'table' then
        return obj
    end

    if seen and seen[obj] then
        return seen[obj]
    end

    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res

    for k, v in pairs(obj) do
        res[Utils.copy(k, s)] = Utils.copy(v, s)
    end

    return res
end

function Utils.prettyPrint(value)
    Pretty.print(Pretty.pretty(value))
end

function Utils.count(table)
    local size = 0

    for _ in pairs(table) do
        size = size + 1
    end

    return size
end

return Utils
