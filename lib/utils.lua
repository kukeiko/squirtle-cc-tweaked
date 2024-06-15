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

---@generic V, K, U
---@param list table<K, V>
---@param mapper fun(item: V, index: K): U
---@return U[]
function Utils.map_v2(list, mapper)
    local mapped = {}

    for key, value in pairs(list) do
        table.insert(mapped, mapper(value, key))
    end

    return mapped
end

---@generic K, V
---@param list table<K, V>
---@return K[]
function Utils.getKeys(list)
    local keys = {}

    for key in pairs(list) do
        table.insert(keys, key)
    end

    return keys
end

---@generic T
---@param list T[]
---@param mapper fun(item: T, index: number): integer
---@return integer
function Utils.sum(list, mapper)
    local sum = 0

    for i = 1, #list do
        sum = sum + mapper(list[i], i)
    end

    return sum
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

---@generic V, K
---@param list table<K, V>
---@param predicate fun(item: V, index: K): boolean
---@return table<K, V>
function Utils.filterMap(list, predicate)
    local filtered = {}

    for key, value in pairs(list) do
        if predicate(value, key) then
            filtered[key] = value
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

---@generic T
---@param list T[]
---@param predicate fun(item: T, index: number): boolean
---@return integer?
function Utils.findIndex(list, predicate)
    for i = 1, #list do
        if predicate(list[i], i) then
            return i
        end
    end
end

---@generic T
---@param list T[]
---@param first integer
---@param last integer
---@return T[]
function Utils.slice(list, first, last)
    local sliced = {}

    if last > #list then
        last = #list
    end

    for i = first or 1, last or #list do
        sliced[#sliced + 1] = list[i]
    end

    return sliced
end

---@generic T
---@param ... T[]
---@return T[]
function Utils.concat(...)
    local lists = {...}
    local concatenated = {}

    for _, list in ipairs(lists) do
        for _, value in pairs(list) do
            table.insert(concatenated, value)
        end
    end

    return concatenated
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

---@generic T
---@param tbl T[]
---@return T[][]
function Utils.chunk(tbl, size)
    assert(size ~= 0, "size can't be 0")

    if #tbl == 0 then
        return {}
    elseif size >= #tbl then
        return {tbl}
    end

    local chunked = {}
    local chunk = {}

    for i = 1, #tbl do
        table.insert(chunk, tbl[i])

        if i == size then
            table.insert(chunked, chunk)
            chunk = {}
        end
    end

    table.insert(chunked, chunk)

    return chunked
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

---@param ... string|number
function Utils.writeStartupFile(...)
    local args = {...}
    local file = fs.open("startup", "w")
    file.write("shell.run(\"" .. table.concat(args, " ") .. "\")")
    file.close()
end

function Utils.deleteStartupFile()
    local path = "startup"

    if fs.exists(path) then
        fs.delete(path)
    end
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

---@param str string
---@param length integer
---@param char string?
---@return string
function Utils.padLeft(str, length, char)
    return string.rep(char or " ", length - #str) .. str
end

---@param str string
---@param length integer
---@param char string?
---@return string
function Utils.padRight(str, length, char)
    return str .. string.rep(char or " ", length - #str)
end

---@param str string
---@param length integer
---@param char string?
---@return string
function Utils.pad(str, length, char)
    return Utils.padLeft(Utils.padRight(str, (length / 2) + #str, char or " "), length, char or " ")
end

---@param str string
---@param length integer
---@return string
function Utils.ellipsis(str, length)
    if #str > length then
        return string.sub(str, 1, length - 3) .. "..."
    else
        return str
    end
end

return Utils
