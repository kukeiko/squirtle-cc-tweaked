package.path = package.path .. ";/?.lua"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local SubwayService = require "lib.features.subway-service"

local function printUsage()
    print("Usage:")
    print("subway-hub <lock-analog-side> [signal-duration] [max-distance]")
end

local function main(args)
    print("[subway-hub v3.0.0-dev] booting...")

    SubwayService.lockAnalogSide = args[1]
    SubwayService.signalDuration = tonumber(args[2]) or SubwayService.signalDuration
    SubwayService.maxDistance = tonumber(args[3]) or SubwayService.maxDistance

    if not SubwayService.lockAnalogSide then
        return printUsage()
    end

    print("[analog-side]", SubwayService.lockAnalogSide)
    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    if not turtle then
        Utils.writeStartupFile("subway-hub", SubwayService.lockAnalogSide, SubwayService.signalDuration, SubwayService.maxDistance)
    end

    EventLoop.run(function()
        Rpc.server(SubwayService)
    end, function()
        SubwayService.start()
    end)
end

main(arg)
