package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local SubwayService = require "services.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-hub <lock-analog-side> [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-hub v2.0.0-dev] booting...")

    SubwayService.lockAnalogSide = args[1]
    SubwayService.signalDuration = tonumber(args[2]) or 7
    SubwayService.maxDistance = tonumber(args[3]) or 5

    if not SubwayService.host then
        return printUsage()
    end

    print("[analog-side]", SubwayService.lockAnalogSide)
    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    Rpc.server(SubwayService)
end

main(arg)
