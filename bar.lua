package.path = package.path .. ";/lib/?.lua"

local Rpc = require "rpc"
local EventLoop = require "event-loop"
local SubwayService = require "services.subway-service"

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
