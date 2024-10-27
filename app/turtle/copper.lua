if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Squirtle = require "lib.squirtle.squirtle-api"

print(string.format("[copper %s] booting...", version()))

local function start()
    while Squirtle.suck("bottom") do
    end

    local home = Squirtle.getPosition()
    local facing = Squirtle.getFacing()
    Squirtle.move("forward", 2)
    Squirtle.turn("left")
    Squirtle.move("forward", 2)

    return home, facing
end

local function doLine()
    for step = 1, 4 do
        if Squirtle.probe("bottom", "minecraft:oxidized_copper") then
            Squirtle.tryMine("bottom")
        end

        if not Squirtle.probe("bottom") then
            if Squirtle.selectItem("minecraft:copper_block") then
                Squirtle.place("bottom")
            end
        end

        if step ~= 4 then
            Squirtle.move("forward", 5)
        end
    end
end

---@param direction "left"|"right"
local function toNextLine(direction)
    Squirtle.turn(direction)
    Squirtle.move("forward", 5)
    Squirtle.turn(direction)
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
            Squirtle.move("forward")
            Squirtle.move("up", 5)
            Squirtle.turn("back")
            Squirtle.move("forward")
        end
    end
end

---@param home Vector
---@param facing integer
local function finish(home, facing)
    Squirtle.navigate(home)
    Squirtle.face(facing)
    Squirtle.dump("bottom")
end

local home, facing = start()
layers(12, 4)
finish(home, facing)
