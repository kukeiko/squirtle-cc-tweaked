package.path = package.path .. ";/?.lua"

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local Resumable = require "lib.apis.turtle.resumable"

EventLoop.run(function()
    while true do
        local resumable = Resumable.new("test/resumable-move-back")

        resumable:setStart(function(args, options)
            print("[test] resumable-move-back")
            Utils.waitForUserToHitEnter("<hit enter to start test>")

            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})

            return {steps = 7}
        end)

        resumable:setResume(function(state, resumed)
            print(string.format("[resume] %s", resumed))
            Utils.waitForUserToHitEnter("<hit enter to continue>")

            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})
        end)

        resumable:addSimulatableMain("move-back", function(state)
            for _ = 1, state.steps do
                TurtleApi.move("back")
            end
        end)

        resumable:setFinish(function(state)
            TurtleApi.move("forward", state.steps)
        end)

        resumable:run()
    end
end)
