if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local TurtleService = require "lib.systems.turtle-service"
local Resumable = require "lib.apis.turtle.resumable"
local buildSmallHouse = require "lib.systems.builders.build-small-house"

local function printUsage()
    print("Usage: small-house <spruce|oak>")
end

EventLoop.run(function()
    EventLoop.runUntil("small-house:stop", function()
        Rpc.host(TurtleService)
    end)
end, function()
    local resumable = Resumable.new("small-house")

    resumable:setStart(function(args, options)
        if args[1] ~= "spruce" and args[1] ~= "oak" then
            return printUsage()
        end

        ---@class SmallHouseAppState
        ---@field theme BuildSmallHouseTheme
        local state = {theme = args[1]}

        TurtleApi.orientate("disk-drive")
        options.requireFuel = true
        options.requireItems = true
        options.requireShulkers = true

        return state
    end)

    resumable:setResume(function()
        TurtleApi.orientate("disk-drive")
    end)

    ---@param state SmallHouseAppState
    resumable:addSimulatableMain("small-house", function(state)
        buildSmallHouse(state.theme)
    end)

    local success, message = pcall(function(...)
        resumable:run(arg)
    end)

    if success then
        EventLoop.queue("small-house:stop")
    else
        print(message)
        TurtleService.error = message
    end
end)
