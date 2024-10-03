package.path = package.path .. ";/?.lua"

local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local SubwayService = require "lib.features.subway-service"

print("station", SubwayService.host)

parallel.waitForAny(function()
    Rpc.server(SubwayService)
end, function()
    while true do
        local _, key = EventLoop.pull("key")
        if key == keys.q then
            return
        end
    end
end)
