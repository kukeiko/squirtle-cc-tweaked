if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local TurtleApi = require "lib.apis.turtle.turtle-api"

print(string.format("[copper %s] booting...", version()))

local function start()
    while TurtleApi.suck("bottom") do
    end

    local home = TurtleApi.getPosition()
    local facing = TurtleApi.getFacing()
    TurtleApi.move("forward", 2)
    TurtleApi.turn("left")
    TurtleApi.move("forward", 2)

    return home, facing
end

local function doLine()
    for step = 1, 4 do
        if TurtleApi.probe("bottom", "minecraft:oxidized_copper") then
            TurtleApi.tryMine("bottom")
        end

        if not TurtleApi.probe("bottom") then
            if TurtleApi.selectItem("minecraft:copper_block") then
                TurtleApi.place("bottom")
            end
        end

        if step ~= 4 then
            TurtleApi.move("forward", 5)
        end
    end
end

---@param direction "left"|"right"
local function toNextLine(direction)
    TurtleApi.turn(direction)
    TurtleApi.move("forward", 5)
    TurtleApi.turn(direction)
end

---@param layers integer
---@param lines integer
local function layers(layers, lines)
    for layer = 1, layers do
        for line = 1, lines do
            doLine()

            if line ~= lines then
                if line % 2 == 0 then
                    if layer % 2 == 0 then
                        toNextLine("right")
                    else
                        toNextLine("left")
                    end

                else
                    if layer % 2 == 0 then
                        toNextLine("left")
                    else
                        toNextLine("right")
                    end
                end
            end
        end

        if layer ~= layers then
            TurtleApi.move("forward")
            TurtleApi.move("up", 5)
            TurtleApi.turn("back")
            TurtleApi.move("forward")
        end
    end
end

---@param home Vector
---@param facing integer
local function finish(home, facing)
    TurtleApi.navigate(home)
    TurtleApi.face(facing)
    TurtleApi.dump("bottom")
end

local home, facing = start()
layers(12, 4)
finish(home, facing)
