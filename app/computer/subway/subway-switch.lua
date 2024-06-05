package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local SubwayService = require "services.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-switch [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-switch v2.0.0-dev] booting...")

    SubwayService.signalDuration = tonumber(args[1]) or 2
    SubwayService.maxDistance = tonumber(args[2]) or 3

    if not SubwayService.host then
        return printUsage()
    end

    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    Rpc.server(SubwayService)
end

main(arg)
