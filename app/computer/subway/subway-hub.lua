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
    print("[subway-hub v3.2.1-dev] booting...")

    SubwayService.lockAnalogSide = args[1]
    SubwayService.signalDuration = tonumber(args[2]) or SubwayService.signalDuration
    SubwayService.maxDistance = tonumber(args[3]) or SubwayService.maxDistance

    if not SubwayService.lockAnalogSide then
        return printUsage()
    end

    print("[analog-side]", SubwayService.lockAnalogSide)
    print("[signal-duration]", SubwayService.signalDuration)
    print("[max-distance]", SubwayService.maxDistance)

    if not turtle and not string.find(os.getComputerLabel(), "dev") then
        Utils.writeStartupFile(string.format("subway-hub %s %d %d", SubwayService.lockAnalogSide, SubwayService.signalDuration, SubwayService.maxDistance))
    else
        print("[debug] skipping creation of startup file")
    end

    EventLoop.run(function()
        Rpc.server(SubwayService)
    end, function()
        SubwayService.start()
    end)
end

main(arg)
