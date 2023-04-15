package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local EventLoop = require "event-loop"
local AppsService = require "services.apps-service"
local DatabaseService = require "services.database-service"

local function printUsage()
    print("Usage:")
    print("update-host <host>")
end

local function main(args)
    print("[update-host v1.0.0] booting...")

    local host = args[1]

    if not host then
        return printUsage()
    end

    print("[host]", host)

    DatabaseService.host = args[1]
    AppsService.host = args[1]

    EventLoop.run(function()
        Rpc.server(AppsService)
    end, function()
        Rpc.server(DatabaseService)
    end)
end

main(arg)
