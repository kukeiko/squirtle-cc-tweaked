package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local AppsService = require "lib.features.apps-service"
local DatabaseService = require "lib.common.database-service"

print("[update v2.0.0-dev] booting...")

local appsClient = Rpc.nearest(AppsService)

if appsClient then
    AppsService.setPocketApps(appsClient.getPocketApps(true), true)
    print("[updated] pocket apps")
end

local databaseClient = Rpc.nearest(DatabaseService)

if databaseClient then
    DatabaseService.setSubwayStations(databaseClient.getSubwayStations())
    print("[updated] database")
end
