package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local SubwayService = require "lib.services.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-switch [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-switch v2.0.0-dev] booting...")

    local signalDuration = tonumber(args[1])
    local maxDistance = tonumber(args[2])

    if not signalDuration or not maxDistance then
        return printUsage()
    end

    SubwayService.signalDuration = signalDuration
    SubwayService.maxDistance = maxDistance

    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    Rpc.server(SubwayService)
end

main(arg)
