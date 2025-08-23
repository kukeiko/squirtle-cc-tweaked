---@param appName string
local function getAppStateFilepath(appName)
    return string.format("/state/apps/%s.json", appName)
end

---@param state table
---@param appName string
local function saveAppState(state, appName)
    local path = getAppStateFilepath(appName)
    local file = fs.open(path, "w")
    file.write(textutils.serializeJSON(state))
    file.close()
end

---@param appName string
---@param defaultState? table
local function loadAppState(appName, defaultState)
    local path = getAppStateFilepath(appName)

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
local function delete(appName)
    local path = getAppStateFilepath(appName)

    if fs.exists(path) then
        fs.delete(path)
    end
end

---@param appName string
---@return boolean
local function has(appName)
    return fs.exists(getAppStateFilepath(appName))
end

return {load = loadAppState, save = saveAppState, delete = delete, has = has}
