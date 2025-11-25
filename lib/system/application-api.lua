local Utils = require "lib.tools.utils"

---@class ApplicationApi
---@field versions table<string, string>
local ApplicationApi = {folder = "apps", versions = {}}

if Utils.isDev() then
    ApplicationApi.folder = "dist"
end

function ApplicationApi.initAppVersions()
    ---@type table<string, string>
    local versions = {}
    local subFolders = {"computer", "pocket", "turtle"}

    for _, subFolder in pairs(subFolders) do
        if fs.isDir(fs.combine(ApplicationApi.folder, subFolder)) then
            for _, fileName in pairs(fs.list(fs.combine(ApplicationApi.folder, subFolder))) do
                local appPath = fs.combine(ApplicationApi.folder, subFolder, fileName)
                ---@type ApplicationMetadata
                local metadata = dofile(appPath)
                versions[appPath] = metadata.version
            end
        end
    end

    ApplicationApi.versions = versions
end

---@param path string
---@param withContent? boolean
---@return Application
function ApplicationApi.getApplication(path, withContent)
    local app = {name = fs.getName(path), version = ApplicationApi.versions[path] or "?", path = path}

    if withContent then
        local file = fs.open(path, "r")
        app.content = file.readAll()
        file.close()
    end

    return app
end

---@param folder string
---@param withContent? boolean
---@param filter? string[]
---@return Application[]
local function getApps(folder, withContent, filter)
    if not fs.isDir(folder) then
        return {}
    end

    withContent = withContent or false

    ---@type string[]
    local fileNames = fs.list(folder)

    if filter and #filter > 0 then
        fileNames = Utils.filter(fileNames, function(fileName)
            return Utils.indexOf(filter, fileName) ~= nil
        end)
    end

    return Utils.map(fileNames, function(fileName)
        local path = fs.combine(folder, fileName)
        ---@type Application
        local app = {name = fileName, version = ApplicationApi.versions[path], path = path}

        if withContent then
            local file = fs.open(path, "r")
            app.content = file.readAll()
            file.close()
        end

        return app
    end)
end

---@param folder string
---@param apps Application[]
local function setApps(folder, apps)
    if Utils.isDev() and os.getComputerLabel() ~= "Database" and os.getComputerLabel() ~= "Playground" then
        return
    end

    for _, app in pairs(apps) do
        local path = fs.combine(folder, app.name)
        local file = fs.open(path, "w")
        file.write(app.content or "")
        file.close()
        ApplicationApi.versions[path] = app.version
    end
end

---@param withContent? boolean
---@param filter? string[]
---@return Application[]
function ApplicationApi.getPocketApps(withContent, filter)
    return getApps(fs.combine(ApplicationApi.folder, "pocket"), withContent, filter)
end

---@param withContent? boolean
---@param name string
---@return Application
function ApplicationApi.getPocketApp(withContent, name)
    local apps = getApps(fs.combine(ApplicationApi.folder, "pocket"), withContent, {name})
    return apps[1] or error(string.format("pocket app %s not found", name))
end

---@param apps Application[]
---@param inRoot? boolean
function ApplicationApi.setPocketApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(ApplicationApi.folder, "pocket")
    end

    setApps(path, apps)
end

---@param withContent? boolean
---@param filter? string[]
---@return Application[]
function ApplicationApi.getTurtleApps(withContent, filter)
    return getApps(fs.combine(ApplicationApi.folder, "turtle"), withContent, filter)
end

---@param withContent? boolean
---@param name string
---@return Application
function ApplicationApi.getTurtleApp(withContent, name)
    local apps = getApps(fs.combine(ApplicationApi.folder, "turtle"), withContent, {name})
    return apps[1] or error(string.format("turtle app %s not found", name))
end

---@param apps Application[]
---@param inRoot? boolean
function ApplicationApi.setTurtleApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(ApplicationApi.folder, "turtle")
    end

    setApps(path, apps)
end

---@param withContent? boolean
---@param names? string[]
---@return Application[]
function ApplicationApi.getComputerApps(withContent, names)
    return getApps(fs.combine(ApplicationApi.folder, "computer"), withContent, names)
end

---@param withContent? boolean
---@param name string
---@return Application
function ApplicationApi.getComputerApp(withContent, name)
    local apps = getApps(fs.combine(ApplicationApi.folder, "computer"), withContent, {name})
    return apps[1] or error(string.format("computer app %s not found", name))
end

---@param apps Application[]
---@param inRoot? boolean
function ApplicationApi.setComputerApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(ApplicationApi.folder, "computer")
    end

    setApps(path, apps)
end

return ApplicationApi
