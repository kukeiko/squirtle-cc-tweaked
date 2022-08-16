local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
local copy = require "utils.copy"
local indexOf = require "utils.index-of"
local Utils = {copy = copy, indexOf = indexOf}

function Utils.concat(a, b)
    for i = 1, #b do
        a[#a + 1] = b[i]
    end

    return a
end

-- https://stackoverflow.com/a/26367080/1611592
---@param tbl table
function Utils.clone(tbl, seen)
    if seen and seen[tbl] then
        return seen[tbl]
    end

    local s = seen or {}
    local res = setmetatable({}, getmetatable(tbl))
    s[tbl] = res

    for k, v in pairs(tbl) do
        res[Utils.clone(k, s)] = Utils.clone(v, s)
    end

    return res
end

function Utils.isEmpty(t)
    for _, _ in pairs(t) do
        return false
    end

    return true
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

function Utils.waitForUserToHitEnter()
    while true do
        local _, key = os.pullEvent("key")
        if (key == keys.enter) then
            break
        end
    end
end

function Utils.writeAutorunFile(args)
    local file = fs.open("startup/" .. args[1] .. ".autorun.lua", "w")
    file.write("shell.run(\"" .. table.concat(args, " ") .. "\")")
    file.close()
end

return Utils
