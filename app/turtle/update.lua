package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local AppsService = require "lib.features.apps-service"

local function main(args)
    print("[update v1.0.0] booting...")

    local appsClient = Rpc.nearest(AppsService)

    if appsClient then
        AppsService.setTurleApps(appsClient.getTurtleApps(true), true)
        print("[updated] turtle apps")
    end
end

main(arg)
