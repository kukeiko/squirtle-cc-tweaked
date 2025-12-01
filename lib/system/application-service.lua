local Rpc = require "lib.tools.rpc"
local ApplicationApi = require "lib.system.application-api"

---@class ApplicationService : Service, ApplicationApi
local ApplicationService = {name = "apps"}
setmetatable(ApplicationService, {__index = ApplicationApi})

function ApplicationService.run()
    ApplicationApi.initializeVersions()
    Rpc.host(ApplicationService)
end

return ApplicationService
