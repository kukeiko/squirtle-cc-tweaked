if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"
local Resumable = require "lib.apis.turtle.resumable"
local buildBoneMealFarm = require "lib.systems.builders.build-bone-meal-farm"

EventLoop.run(function()
    print(string.format("[bone-meal %s] booting...", version()))

    local resumable = Resumable.new("bone-meal")

    resumable:setStart(function(_, options)
        options.requireFuel = true
        options.requireItems = true
        options.requireShulkers = true
        options.additionalRequiredItems = {[ItemApi.diskDrive] = 1}

        ---@class BoneMealAppState
        local state = {home = TurtleApi.getPosition(), facing = TurtleApi.getFacing()}

        return state
    end)

    resumable:setResume(function(state, resumed)
        TurtleApi.orientate("disk-drive")
    end)

    resumable:addSimulatableMain("build", function()
        buildBoneMealFarm()
    end)

    ---@param state BoneMealAppState
    resumable:setFinish(function(state)
        TurtleApi.navigate(state.home)
        TurtleApi.face(state.facing)
    end)

    resumable:run()
end)
