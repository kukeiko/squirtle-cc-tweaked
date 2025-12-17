local ApplicationApi = require "lib.system.application-api"

---@class ApplicationService : Service, ApplicationApi
local ApplicationService = {name = "apps"}

---@param platform Platform
---@param filter? string[]
---@param withContent? boolean
---@return Application[]
function ApplicationService.getApplications(platform, filter, withContent)
    local platformFolder = fs.combine(".kita/app", platform)
    return ApplicationApi.readApps(platformFolder, filter, withContent)
end

---@param platform Platform
---@param name string
---@param withContent? boolean
---@return Application
function ApplicationService.getApplication(platform, name, withContent)
    local apps = ApplicationService.getApplications(platform, {name}, withContent)

    return apps[1] or error(string.format("%s app %s not found", platform, name))
end

return ApplicationService
