local Rpc = require "lib.tools.rpc"
local DatabaseApi = require "lib.apis.database-api"
local DatabaseService = require "lib.systems.database.database-service"
local AppsService = require "lib.systems.runtime.apps-service"

---@class UpdateService : Service
local UpdateService = {name = "update"}

---@param apps? string[]
function UpdateService.update(apps)
    local appsClient = Rpc.nearest(AppsService)
    local databaseClient = Rpc.nearest(DatabaseService)

    if turtle then
        AppsService.setTurleApps(appsClient.getTurtleApps(true, apps), true)
        print("[updated] turtle apps")
    elseif pocket then
        AppsService.setPocketApps(appsClient.getPocketApps(true, apps), true)
        print("[updated] pocket apps")
        DatabaseApi.setSubwayStations(databaseClient.getSubwayStations())
        print("[updated] subway stations")
    else
        AppsService.setComputerApps(appsClient.getComputerApps(true, apps), true)
        print("[updated] computer apps")
        DatabaseApi.setCraftingRecipes(databaseClient.getCraftingRecipes())
        print("[updated] crafting recipes")
    end
end

return UpdateService
