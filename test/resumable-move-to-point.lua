package.path = package.path .. ";/?.lua"

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Vector = require "lib.common.vector"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"

EventLoop.run(function()
    while true do
        local resumable = Resumable.new("test/resumable-move-to-point")

        resumable:setStart(function(args, options)
            print("[test] resumable-move-to-point")
            Utils.waitForUserToHitEnter("<hit enter to start test>")

            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})

            options.requireFuel = true
            
            ---@class TestResumableMoveToPointState
            local state = {target = Vector.create(33, 60, -17), home = TurtleApi.getPosition(), facing = TurtleApi.getFacing()}

            return state
        end)

        resumable:setResume(function(state, resumed)
            print(string.format("[resume] %s", resumed))
            Utils.waitForUserToHitEnter("<hit enter to continue>")

            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})
        end)

        ---@param state TestResumableMoveToPointState
        resumable:addSimulatableMain("move-to-point", function(state)
            TurtleApi.moveToPoint(state.target)
            TurtleApi.moveToPoint(state.home)
        end)

        ---@param state TestResumableMoveToPointState
        resumable:setFinish(function(state)
            TurtleApi.face(state.facing)
        end)

        resumable:run()
    end
end)
