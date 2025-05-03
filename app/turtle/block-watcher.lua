if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local RemoteService = require "lib.systems.runtime.remote-service"
local Shell = require "lib.ui.shell"

local blockSide = arg[1]
local signalSide = arg[2]

if not blockSide or not signalSide then
    print("Usage:")
    print("block-watcher <block-side> <signal-side>")
    return
end

Utils.writeStartupFile(string.format("block-watcher %s %s", blockSide, signalSide))

Shell:addWindow("Game", function()
    TurtleApi.select(1)
    redstone.setOutput(signalSide, true)

    while true do
        redstone.setOutput(signalSide, not TurtleApi.compare(blockSide))
        os.sleep(1)
    end
end)

Shell:addWindow("RPC", function()
    RemoteService.run({"block-watcher"})
end)

Shell:run()
