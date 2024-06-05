package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local EventLoop = require "event-loop"
local AppsService = require "services.apps-service"
local DatabaseService = require "services.database-service"

local function main()
    print("[update-host v2.0.0-dev] booting...")

    EventLoop.run(function()
        Rpc.server(AppsService)
    end, function()
        Rpc.server(DatabaseService)
    end)
end

main()
