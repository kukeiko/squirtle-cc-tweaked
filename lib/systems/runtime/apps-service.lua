local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"

---@class AppsService : Service
---@field versions table<string, string>
local AppsService = {name = "apps", folder = "apps", versions = {}}

if Utils.isDev() then
    AppsService.folder = "dist"
end

local function initAppVersions()
    ---@type table<string, string>
    local versions = {}
    local subFolders = {"computer", "pocket", "turtle"}

    for _, subFolder in pairs(subFolders) do
        if fs.isDir(fs.combine(AppsService.folder, subFolder)) then
            for _, fileName in pairs(fs.list(fs.combine(AppsService.folder, subFolder))) do
                local appPath = fs.combine(AppsService.folder, subFolder, fileName)
                ---@type ApplicationMetadata
                local metadata = dofile(appPath)
                versions[appPath] = metadata.version
                print(string.format("[%s] %s @ %s", subFolder, fileName, versions[appPath]))
            end
        end
    end

    AppsService.versions = versions
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
        local app = {name = fileName, version = AppsService.versions[path], path = path}

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
    if Utils.isDev() and os.getComputerLabel() ~= "Database" then
        return
    end

    for _, app in pairs(apps) do
        local path = fs.combine(folder, app.name)
        local file = fs.open(path, "w")
        file.write(app.content or "")
        file.close()
        AppsService.versions[path] = app.version
    end
end

function AppsService.run()
    initAppVersions()
    Rpc.host(AppsService)
end

---@param withContent? boolean
---@param filter? string[]
---@return Application[]
function AppsService.getPocketApps(withContent, filter)
    return getApps(fs.combine(AppsService.folder, "pocket"), withContent, filter)
end

---@param apps Application[]
---@param inRoot? boolean
function AppsService.setPocketApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(AppsService.folder, "pocket")
    end

    setApps(path, apps)
end

---@param withContent? boolean
---@param filter? string[]
---@return Application[]
function AppsService.getTurtleApps(withContent, filter)
    return getApps(fs.combine(AppsService.folder, "turtle"), withContent, filter)
end

---@param apps Application[]
---@param inRoot? boolean
function AppsService.setTurleApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(AppsService.folder, "turtle")
    end

    setApps(path, apps)
end

---@param withContent? boolean
---@param filter? string[]
---@return Application[]
function AppsService.getComputerApps(withContent, filter)
    return getApps(fs.combine(AppsService.folder, "computer"), withContent, filter)
end

---@param apps Application[]
---@param inRoot? boolean
function AppsService.setComputerApps(apps, inRoot)
    local path = "/"

    if not inRoot then
        path = fs.combine(AppsService.folder, "computer")
    end

    setApps(path, apps)
end

return AppsService
