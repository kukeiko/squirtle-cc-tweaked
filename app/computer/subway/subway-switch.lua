package.path = package.path .. ";/?.lua"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local SubwayService = require "lib.features.subway-service"

print("[subway-switch v3.0.0-dev] booting...")

if not turtle then
    Utils.writeStartupFile("subway-switch")
end

SubwayService.maxDistance = 10
Rpc.server(SubwayService)
