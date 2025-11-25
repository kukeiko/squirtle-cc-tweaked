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
local EditEntity = require "lib.ui.edit-entity"

EventLoop.run(function()
    EventLoop.runUntil("dig-area:stop", function()
        Rpc.host(TurtleService)
    end)
end, function()
    local resumable = Resumable.new("dig-area")

    resumable:setStart(function(_, options)
        local editEntity = EditEntity.new("Options")
        editEntity:addInteger("depth", "Depth", {validate = EditEntity.greaterZero})
        editEntity:addInteger("width", "Width", {validate = EditEntity.notZero})
        editEntity:addInteger("height", "Height", {validate = EditEntity.notZero})
        editEntity:addBoolean("returnHome", "Return Home")

        ---@class DigAreaAppArguments
        ---@field depth integer
        ---@field width integer
        ---@field height integer
        ---@field returnHome boolean
        local arguments = editEntity:run({returnHome = true}, "data/app/dig-area-options.json")

        if not arguments then
            return
        end

        ---@class DigAreaAppState
        ---@field depth integer
        ---@field width integer
        ---@field height integer
        ---@field returnHome boolean
        ---@field home Vector
        ---@field facing integer
        local state = {
            depth = arguments.depth,
            width = arguments.width,
            height = arguments.height,
            returnHome = arguments.returnHome,
            home = TurtleApi.getPosition(),
            facing = TurtleApi.orientate("disk-drive")
        }

        options.requireFuel = true
        Utils.writeStartupFile("dig-area")

        -- [todo] ❌ band-aid fix to make space for disk-drive/shulker-box
        if state.height > 0 then
            TurtleApi.dig("up")
        else
            TurtleApi.dig("down")
        end

        return state
    end)

    resumable:setResume(function()
        TurtleApi.orientate("disk-drive")
    end)

    ---@param state DigAreaAppState
    resumable:addSimulatableMain("dig-area", function(state)
        TurtleApi.digArea(state.depth, state.width, state.height)

        if state.returnHome then
            TurtleApi.moveToPoint(state.home)
            TurtleApi.face(state.facing)
        end
    end)

    resumable:setFinish(function()
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
