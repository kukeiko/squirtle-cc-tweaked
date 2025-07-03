local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)

local Utils = {}

---@generic K, V
---@param list table<K, V>
---@param item V
---@return integer?
function Utils.indexOf(list, item)
    for i = 1, #list do
        if list[i] == item then
            return i
        end
    end
end

---@generic K, V
---@param list table<K, V>
---@param item V
function Utils.remove(list, item)
    local index = Utils.indexOf(list, item)

    if index then
        table.remove(list, index)
    end
end

---@param str string
---@return string
function Utils.trim(str)
    str = str:gsub("^%s+", ""):gsub("%s+$", "")

    return str
end

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

---Creates a shallow copy of the given table.
---@generic T: table
---@param tbl T
---@return T
function Utils.copy(tbl)
    local copy = {}

    for k, v in pairs(tbl) do
        copy[k] = v
    end

    return copy
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

---Creates a deep copy of the given table.
---https://stackoverflow.com/a/26367080/1611592
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

---@generic V, K, U
---@param list table<K, V>
---@param mapper fun(item: V, index: K): U
---@return U[]
function Utils.map(list, mapper)
    local mapped = {}

    for key, value in pairs(list) do
        table.insert(mapped, mapper(value, key))
    end

    return mapped
end

---@generic V, K, U
---@param list table<K, V>
---@param mapper fun(item: V, index: K): U[]
---@return U[]
function Utils.flatMap(list, mapper)
    local mapped = {}

    for key, value in pairs(list) do
        for _, nestedValue in pairs(mapper(value, key)) do
            table.insert(mapped, nestedValue)
        end
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

---@generic K, V
---@param list V[]
---@param selector fun(item: V) : K
---@return table<K, V>
function Utils.toMap(list, selector)
    local map = {}

    for _, element in pairs(list) do
        map[selector(element)] = element
    end

    return map
end

---@generic K, V
---@param map V[]
---@return V[]
function Utils.toList(map)
    local list = {}

    for _, value in pairs(map) do
        table.insert(list, value)
    end

    return list
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

---@generic V, K, U
---@param list table<K, V>
---@param predicate fun(item: V, index: K): boolean
---@param project fun(item: V, index: K): U
---@return U[]
function Utils.filterMapProjectList(list, predicate, project)
    local filtered = {}

    for key, value in pairs(list) do
        if predicate(value, key) then
            table.insert(filtered, project(value, key))
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
    local _, index = Utils.find(list, predicate)

    return index
end

---@generic K, V
---@param list table<K, V>
---@param predicate fun(item: V, index: K): boolean
---@return boolean
function Utils.every(list, predicate)
    for key, value in pairs(list) do
        if not predicate(value, key) then
            return false
        end
    end

    return true
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

---@generic T
---@param tbl T[]
---@return T[]
function Utils.reverse(tbl)
    local reversed = {}

    for i = #tbl, 1, -1 do
        table.insert(reversed, tbl[i])
    end

    return reversed
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

        if i % size == 0 then
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

---@param text? string
function Utils.waitForUserToHitEnter(text)
    if text then
        print(text)
    end

    while true do
        local _, key = os.pullEvent("key")

        if key == keys.enter or key == keys.numPadEnter then
            break
        end
    end
end

function Utils.isDev()
    return fs.exists("package.json") or fs.exists("is-dev")
end

---@param ... string
function Utils.writeStartupFile(...)
    if Utils.isDev() then
        print("[skip] startup file creation")
        return
    end

    local programs = {...}
    local file = fs.open("startup", "w")

    for i = 1, #programs do
        file.writeLine(string.format("shell.run(\"%s\")", programs[i]))
    end

    file.close()
end

function Utils.deleteStartupFile()
    if Utils.isDev() then
        print("[skip] startup file deletion")
        return
    end

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

    local content = file.readAll()
    file.close()

    return textutils.unserialiseJSON(content, {parse_empty_array = false})
end

---@param path string
---@param data table
function Utils.writeJson(path, data)
    local file = fs.open(path, "w")
    file.write(textutils.serialiseJSON(data, {allow_repetitions = true}))
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
    local open = length - #str

    if open <= 0 then
        return str
    end

    char = char or " "
    local left = math.floor(open / 2)
    local right = math.ceil(open / 2)

    return string.rep(char, left) .. str .. string.rep(char, right)
end

---@param subject string
---@param str string
---@return boolean
function Utils.startsWith(subject, str)
    return string.sub(subject, #str) == str
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

---@param current number
---@param total number
---@param x integer|nil
---@param y integer|nil
---@return integer, integer
function Utils.printProgress(current, total, x, y)
    if not x or not y then
        x, y = term.getCursorPos()
    end

    ---@type integer
    local termWidth = term.getSize()
    local numProgressChars = termWidth - 2

    local numCharsDone = math.ceil((current / total) * numProgressChars)
    local numCharsOpen = numProgressChars - numCharsDone
    term.setCursorPos(x, y)
    term.write("[" .. string.rep("=", numCharsDone) .. string.rep(" ", numCharsOpen) .. "]")

    return x, y
end

---@param timeout integer
---@return "timeout" | "key"
function Utils.waitForTimeoutOrUntilKeyEvent(timeout)
    local steps = 10
    local x, y = Utils.printProgress(0, steps)

    local first = parallel.waitForAny(function()
        local timeoutTick = timeout / steps

        for i = 1, steps do
            os.sleep(timeoutTick)
            Utils.printProgress(i, steps, x, y)
        end
    end, function()
        os.pullEvent("key")
        Utils.printProgress(steps, steps, x, y)
    end)

    if first == 1 then
        return "timeout"
    else
        return "key"
    end
end

---@param timer unknown
---@param timeout integer
---@return unknown
function Utils.restartTimer(timer, timeout)
    if timer then
        os.cancelTimer(timer)
    end

    return os.startTimer(timeout)
end

function Utils.getTime24()
    ---@diagnostic disable-next-line: param-type-mismatch
    local time = os.time("local")
    local hours = tostring(math.floor(time))
    local minutes = tostring(math.floor((time % 1) * 60))
    local seconds = tostring(math.floor((time * 100) % 1 * 60))

    if #hours < 2 then
        hours = "0" .. hours
    end

    if #minutes < 2 then
        minutes = "0" .. minutes
    end

    if #seconds < 2 then
        seconds = "0" .. seconds
    end

    return string.format("%s:%s:%s", hours, minutes, seconds)
end

---@param str string
function Utils.escapePpattern(str)
    return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

return Utils
