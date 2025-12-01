local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local DatabaseApi = require "lib.database.database-api"
local DatabaseService = require "lib.database.database-service"
local AppsService = require "lib.system.application-service"

---@class UpdateService : Service
local UpdateService = {name = "update"}

---@param apps? string[]
function UpdateService.update(apps)
    local appsClient = Rpc.nearest(AppsService)
    local databaseClient = Rpc.nearest(DatabaseService)
    local platform = Utils.getPlatform()

    AppsService.addApplications(platform, appsClient.getApplications(platform, apps, true), true)
    print(string.format("[updated] % apps", platform))

    if platform == "pocket" then
        DatabaseApi.setSubwayStations(databaseClient.getSubwayStations())
        print("[updated] subway stations")
    end
end

return UpdateService
