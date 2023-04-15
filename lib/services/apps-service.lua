local Utils = require "utils"

---@class AppsService : Service
local AppsService = {name = "apps", folder = "apps"}

---@param folder string
---@param withContent? boolean
---@return Application[]
local function getApps(folder, withContent)
    if not fs.isDir(folder) then
        return {}
    end

    withContent = withContent or false

    return Utils.map(fs.list(folder), function(fileName)
        ---@type Application
        local app = {name = fileName}

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
    for _, app in pairs(apps) do
        local file = fs.open(fs.combine(folder, app.name), "w")
        file.write(app.content or "")
        file.close()
    end
end

---@param withContent? boolean
---@return Application[]
function AppsService.getPocketApps(withContent)
    return getApps(fs.combine(AppsService.folder, "pocket"), withContent)
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
---@return Application[]
function AppsService.getTurtleApps(withContent)
    return getApps(fs.combine(AppsService.folder, "turtle"), withContent)
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
---@return Application[]
function AppsService.getComputerApps(withContent)
    return getApps(fs.combine(AppsService.folder, "computer"), withContent)
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
