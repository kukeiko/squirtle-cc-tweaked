local Rpc = require "lib.tools.rpc"
local ApplicationApi = require "lib.system.application-api"

---@class AppsService : Service, ApplicationApi
local AppsService = {name = "apps"}
setmetatable(AppsService, {__index = ApplicationApi})

function AppsService.run()
    ApplicationApi.initAppVersions()
    Rpc.host(AppsService)
end

return AppsService
