package.path = package.path .. ";/?.lua"

local Rpc = require "lib.rpc"
local EventLoop = require "lib.event-loop"
local SubwayService = require "lib.services.subway-service"

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
