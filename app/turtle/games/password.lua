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
local password = arg[1]
local signalSide = arg[2]

if not password or not signalSide then
    print("Usage:")
    print("password <password> <signal-side>")

    return
end

Utils.writeStartupFile(string.format("password %s %s", password, signalSide))

EventLoop.run(function()
    redstone.setOutput(signalSide, false)

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        print("What's the password?")
        local input = io.read()

        if input == password then
            print("Correct!")
            redstone.setOutput(signalSide, true)
            EventLoop.pull("never")
        else
            print("WRONG!")

            for _ = 1, 7 do
                print("TERMINATE!")
                os.sleep(.5)
                turtle.attack()
            end
        end
    end
end)
