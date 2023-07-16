package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local SubwayService = require "services.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-hub <host> <lock-analog-side> [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-hub v1.0.1] booting...")

    SubwayService.host = args[1]
    SubwayService.lockAnalogSide = args[2]
    SubwayService.signalDuration = tonumber(args[3]) or 7
    SubwayService.maxDistance = tonumber(args[4]) or 5

    if not SubwayService.host then
        return printUsage()
    end

    print("[host]", SubwayService.host)
    print("[analog-side]", SubwayService.lockAnalogSide)
    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    Rpc.server(SubwayService)
end

main(arg)
