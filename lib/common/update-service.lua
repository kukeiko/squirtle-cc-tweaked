local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"
local AppsService = require "lib.features.apps-service"

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
        DatabaseService.setSubwayStations(databaseClient.getSubwayStations())
        print("[updated] subway stations")
    else
        AppsService.setComputerApps(appsClient.getComputerApps(true, apps), true)
        print("[updated] computer apps")
        DatabaseService.setCraftingRecipes(databaseClient.getCraftingRecipes())
        print("[updated] crafting recipes")
    end
end

return UpdateService
