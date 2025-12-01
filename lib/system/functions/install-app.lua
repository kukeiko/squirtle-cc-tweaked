local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ApplicationApi = require "lib.system.application-api"

---@param applicationService ApplicationService|RpcClient
---@param name string
return function(applicationService, name)
    local platform = Utils.getPlatform()
    local app = applicationService.getApplication(platform, name, true)
    ApplicationApi.addApplications(platform, {app}, false)
    EventLoop.queue("shell:app-installed")
end
