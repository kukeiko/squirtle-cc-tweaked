package.path = package.path .. ";/?.lua"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local AppsService = require "lib.features.apps-service"
local DatabaseService = require "lib.common.database-service"

local function main()
    print("[update-host v2.0.0-dev] booting...")

    Utils.writeStartupFile("update-host")

    EventLoop.run(function()
        Rpc.server(AppsService)
    end, function()
        Rpc.server(DatabaseService)
    end)
end

main()
