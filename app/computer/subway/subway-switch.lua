package.path = package.path .. ";/?.lua"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local SubwayService = require "lib.features.subway-service"

print("[subway-switch v3.2.1-dev] booting...")

SubwayService.maxDistance = tonumber(arg[1]) or 15

if not turtle and not string.find(os.getComputerLabel(), "dev") then
    Utils.writeStartupFile(string.format("subway-switch %d", SubwayService.maxDistance))
else
    print("[debug] skipping creation of startup file")
end

print("[max-distance]", SubwayService.maxDistance)
Rpc.server(SubwayService)
