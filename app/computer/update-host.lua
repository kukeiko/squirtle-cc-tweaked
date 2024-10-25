package.path = package.path .. ";/?.lua"

local version = require "version"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local AppsService = require "lib.features.apps-service"
local DatabaseService = require "lib.common.database-service"
local QuestService = require "lib.common.quest-service"

local function main()
    print(string.format("[update-host %s] booting...", version()))
    Utils.writeStartupFile("update-host")

    EventLoop.run(function()
        Rpc.server(AppsService)
    end, function()
        Rpc.server(DatabaseService)
    end, function()
        Rpc.server(QuestService)
    end)
end

main()
