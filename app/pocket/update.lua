package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local AppsService = require "services.apps-service"
local DatabaseService = require "common.database-service"

local function main(args)
    print("[update v1.0.0] booting...")

    local appsClient = Rpc.nearest(AppsService)

    if appsClient then
        AppsService.setPocketApps(appsClient.getPocketApps(true), true)
        print("[updated] pocket apps")
    end

    local databaseClient = Rpc.nearest(DatabaseService)

    if databaseClient then
        DatabaseService.setSubwayStations(databaseClient.getSubwayStations())
        DatabaseService.setSubwayTracks(databaseClient.getSubwayTracks())
        print("[updated] database")
    end
end

main(arg)
