local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"

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
                local version = dofile(appPath) --[[@as fun():string]]
                versions[appPath] = version()
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
        ---@type Application
        local app = {name = fileName, version = AppsService.versions[fs.combine(folder, fileName)]}

        if withContent then
            local file = fs.open(fs.combine(folder, fileName), "r")
            app.content = file.readAll()
            file.close()
        end

        return app
    end)
end

---@param folder string
---@param apps Application[]
local function setApps(folder, apps)
    if Utils.isDev() then
        return
    end

    for _, app in pairs(apps) do
        local file = fs.open(fs.combine(folder, app.name), "w")
        file.write(app.content or "")
        file.close()
    end
end

function AppsService.run()
    initAppVersions()
    Rpc.server(AppsService)
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
