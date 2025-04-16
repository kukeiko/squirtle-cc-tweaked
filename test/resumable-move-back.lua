package.path = package.path .. ";/?.lua"

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local TurtleApi = require "lib.apis.turtle.turtle-api"

EventLoop.run(function()
    while true do
        local success, message = TurtleApi.runResumable("test/resumable-walk-back", {}, function(args)
            print("[test] resumable-walk-back")
            Utils.waitForUserToHitEnter("<hit enter to start test>")
            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})

            return {steps = 7}
        end, function(state)
            print("[main]")
            for _ = 1, state.steps do
                local wasSimulating = TurtleApi.isSimulating()
                TurtleApi.move("back")

                if not wasSimulating and not TurtleApi.isSimulating() then
                    os.reboot()
                end
            end
        end, function(state)
            TurtleApi.locate()
            TurtleApi.orientate("disk-drive", {"top"})
        end, function(state)
            print("[ok] finished")
            TurtleApi.move("forward", state.steps)
        end)

        if not success then
            error(message)
        end
    end
end)
