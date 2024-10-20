package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local AppsService = require "lib.features.apps-service"

print("[update v2.0.0]")

local appsClient = Rpc.nearest(AppsService)

if appsClient then
    AppsService.setComputerApps(appsClient.getComputerApps(true), true)
    print("[updated] computer apps")
end
