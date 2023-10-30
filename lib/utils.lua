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

---@param list table
---@param value unknown
---@return boolean
function Utils.contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end

    return false
end

local function clone(value, seen)
    if type(value) ~= "table" then
        return value
    end

    if seen and seen[value] then
        return seen[value]
    end

    local s = seen or {}
    local res = setmetatable({}, getmetatable(value))
    s[value] = res

    for k, v in pairs(value) do
        res[clone(k, s)] = clone(v, s)
    end

    return res
end

-- https://stackoverflow.com/a/26367080/1611592
---@generic T: table
---@param tbl T
---@return T
function Utils.clone(tbl)
    return clone(tbl, {})
end

function Utils.isEmpty(t)
    for _, _ in pairs(t) do
        return false
    end

    return true
end

---@generic T, U
---@param list T[]
---@param mapper fun(item: T, index: number): U
---@return U[]
function Utils.map(list, mapper)
    local mapped = {}

    for i = 1, #list do
        table.insert(mapped, mapper(list[i], i))
    end

    return mapped
end

---@generic T
---@param list T[]
---@param property string
---@return T[]
function Utils.toMap(list, property)
    local map = {}

    for _, element in pairs(list) do
        local id = element[property]

        if type(id) ~= "string" then
            error("id must be of type string")
        end

        map[id] = element
    end

    return map
end

---@generic T
---@param list T[]
---@param predicate fun(item: T, index: number): boolean
---@return T[]
function Utils.filter(list, predicate)
    local filtered = {}

    for i = 1, #list do
        if predicate(list[i], i) then
            table.insert(filtered, list[i])
        end
    end

    return filtered
end

---@generic T
---@param list T[]
---@param predicate fun(item: T, index: number): boolean
---@return T|nil, integer|nil
function Utils.find(list, predicate)
    for i = 1, #list do
        if predicate(list[i], i) then
            return list[i], i
        end
    end
end

function Utils.reverse(list)
    for i = 1, #list / 2, 1 do
        list[i], list[#list - i + 1] = list[#list - i + 1], list[i]
    end

    return list
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

---@generic T
---@param tbl T[]
---@return T?
function Utils.first(tbl)
    for _, item in pairs(tbl) do
        return item
    end
end

function Utils.firstEmptySlot(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
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

---@param path string
---@return table?
function Utils.readJson(path)
    local file = fs.open(path, "r")

    if not file then
        return
    end

    return textutils.unserializeJSON(file.readAll())
end

---@param path string
---@param data table
function Utils.writeJson(path, data)
    local file = fs.open(path, "w")
    file.write(textutils.serialiseJSON(data))
    file.close()
end

return Utils
