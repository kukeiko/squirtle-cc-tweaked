local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
local copy = require "utils.copy"
local indexOf = require "utils.index-of"
local Utils = {copy = copy, indexOf = indexOf}

---@param list table
---@param values table
---@return table
function Utils.push(list, values)
    for i = 1, #values do
        list[#list + 1] = values[i]
    end

    return list
end

-- https://stackoverflow.com/a/26367080/1611592
---@generic T: table
---@param tbl T
---@return T
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

---@generic T, U
---@param list T[]
---@param mapper fun(item: T, index: number) : U
---@return U[]
function Utils.map(list, mapper)
    local mapped = {}

    for i = 1, #list do
        table.insert(mapped, mapper(list[i], i))
    end

    return mapped
end

---@param list table
---@param predicate function
---@return table
function Utils.filter(list, predicate)
    local filtered = {}

    for i = 1, #list do
        if predicate(list[i], i) then
            table.insert(filtered, list[i])
        end
    end

    return filtered
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
