local Utils = require "lib.tools.utils"

---@class ApplicationApi
---@field versions table<string, string>
local ApplicationApi = {folder = "apps", versions = {}}

if Utils.isDev() then
    ApplicationApi.folder = "dist"
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

function ApplicationApi.initializeVersions()
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

---@param platform Platform
---@param filter? string[]
---@param withContent? boolean
---@return Application[]
function ApplicationApi.getApplications(platform, filter, withContent)
    local folder = fs.combine(ApplicationApi.folder, platform)

    return getApps(folder, withContent, filter)
end

---@param platform Platform
---@param name string
---@param withContent? boolean
---@return Application
function ApplicationApi.getApplication(platform, name, withContent)
    local apps = ApplicationApi.getApplications(platform, {name}, withContent)

    return apps[1] or error(string.format("%s app %s not found", platform, name))
end

---@param platform Platform
---@param apps Application[]
---@param inRoot? boolean
function ApplicationApi.addApplications(platform, apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(ApplicationApi.folder, platform)
    end

    setApps(path, apps)
end

return ApplicationApi
