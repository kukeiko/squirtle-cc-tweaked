package.path = package.path .. ";/lib/?.lua"

local Rpc = require "rpc"
local EventLoop = require "event-loop"
local SubwayService = require "subway.subway-service"

SubwayService.id = "bar-station"

parallel.waitForAny(function()
    Rpc.server(SubwayService, SubwayService.id)
end, function()
    while true do
        local _, key = EventLoop.pull("key")
        if key == keys.q then
            return
        end
    end
end)
