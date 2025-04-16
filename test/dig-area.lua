package.path = package.path .. ";/?.lua"

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"

EventLoop.run(function()
    while true do
        print("[test] dig-area")
        Utils.waitForUserToHitEnter("<hit enter to start test>")
        TurtleApi.digArea(2, 2, 4)
    end
end)
