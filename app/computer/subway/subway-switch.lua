package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local SubwayService = require "services.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-switch <host> [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-switch v1.0.0] booting...")

    SubwayService.host = args[1]
    SubwayService.signalDuration = tonumber(args[2]) or 2
    SubwayService.maxDistance = 3

    if not SubwayService.host then
        return printUsage()
    end

    print("[host]", SubwayService.host)
    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    Rpc.server(SubwayService)
end

main(arg)
