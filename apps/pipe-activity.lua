package.path = package.path .. ";/libs/?.lua"

local Utils = require "utils";

print("[pipe-activity @ 1.0.2]")

if arg[1] == "autorun" then
    Utils.writeAutorunFile({"pipe-activity"})
end

local lightSignalToggle = true
local signalBack = false
local timeOfLastSignal = 0

function signalTick()
    while true do
        os.pullEvent("redstone")

        if redstone.getInput("back") and not signalBack then
            signalBack = true
            timeOfLastSignal = Utils.timestamp()
        elseif signalBack then
            signalBack = false
        end
    end
end

function lightTick()
    while true do
        os.sleep(1)

        if Utils.timestamp() - timeOfLastSignal <= 3 then
            redstone.setOutput("front", lightSignalToggle)
            lightSignalToggle = not lightSignalToggle
        end
    end
end

parallel.waitForAll(signalTick, lightTick)
