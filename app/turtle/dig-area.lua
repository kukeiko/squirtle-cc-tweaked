if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local TurtleApi = require "lib.turtle.turtle-api"
local TurtleService = require "lib.turtle.turtle-service"
local Resumable = require "lib.turtle.resumable"

EventLoop.run(function()
    EventLoop.runUntil("dig-area:stop", function()
        Rpc.host(TurtleService)
    end)
end, function()
    local resumable = Resumable.new("dig-area")

    resumable:setStart(function(args, options)
        local function printUsage()
            print("Usage:")
            print("dig-area <depth> <width> <height>")
            print("(negative numbers possible)")
        end

        local depth = tonumber(args[1])
        local width = tonumber(args[2])
        local height = tonumber(args[3])

        if not depth or not width or not height or depth == 0 or width == 0 or height == 0 then
            printUsage()
            return nil
        end

        -- [todo] ❌ should dig above/below if within bounds to place disk drive
        -- [todo] ❌ should dig above/below/forward if within bounds to read shulkers
        ---@class DigAreaAppState
        local state = {
            depth = depth,
            width = width,
            height = height,
            home = TurtleApi.getPosition(),
            facing = TurtleApi.orientate("disk-drive")
        }

        options.requireFuel = true
        Utils.writeStartupFile("dig-area")

        return state
    end)

    resumable:setResume(function()
        TurtleApi.orientate("disk-drive")
    end)

    ---@param state DigAreaAppState
    resumable:addSimulatableMain("dig-area", function(state)
        TurtleApi.digArea(state.depth, state.width, state.height, state.home, state.facing)
    end)

    resumable:setFinish(function ()
        Utils.deleteStartupFile()
    end)

    local success, message = pcall(function(...)
        resumable:run(arg)
    end)

    if success then
        EventLoop.queue("dig-area:stop")
    else
        print(message)
        TurtleService.error = message
    end
end)
