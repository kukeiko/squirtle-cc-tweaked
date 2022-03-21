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
    if type(obj) ~= "table" then
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

function Utils.readPositiveInteger()
    local int = 0

    repeat
        int = tonumber(io.read())
    until int ~= nil and int > 0

    return math.floor(int)
end

function Utils.writeAutorunFile(args)
    local file = fs.open("startup/" .. args[1] .. ".autorun.lua", "w")
    file.write("shell.run(\"" .. table.concat(args, " ") .. "\")")
    file.close()
end

---@return boolean
function Utils.hasAppState(appName)
    return fs.exists(Utils.getAppStateFilepath(appName))
end

---@param state table
function Utils.saveAppState(state, appName)
    local path = Utils.getAppStateFilepath(appName)
    local file = fs.open(path, "w")
    file.write(textutils.serializeJSON(state))
    file.close()
end

---@param appName string
---@param defaultState? table
function Utils.loadAppState(appName, defaultState)
    local path = Utils.getAppStateFilepath(appName)

    if not fs.exists(path) then
        return defaultState
    end

    local state = defaultState or {}
    local file = fs.open(path, "r")
    local stateOnDisk, message = textutils.unserializeJSON(file.readAll())
    file.close()

    if not stateOnDisk then
        return state, false, message
    end

    for key, value in pairs(stateOnDisk) do
        state[key] = value
    end

    return state
end

---@param appName string
function Utils.getAppStateFilepath(appName)
    return string.format("/state/apps/%s.json", appName)
end

---@param name string
---@param version string
---@param duration? number
function Utils.printAppBootScreen(name, version, duration)
    print(string.format("[%s @ %s]", name, version))

    duration = duration or 1

    if duration > 0 then
        os.sleep(duration)
    end
end

function Utils.noop()
    -- intentionally do nothing
end

function Utils.timestamp()
    return os.time() * 60 * 60 / 100
end

return Utils
