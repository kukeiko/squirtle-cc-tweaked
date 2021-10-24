package.path = package.path .. ";/?.lua"

local Turtle = require "squirtle.libs.turtle"
local Cardinal = require "squirtle.libs.cardinal"
local Vector = require "squirtle.libs.vector"
local PathFinding = require "squirtle.libs.path-finding"
local World = require "squirtle.libs.geo.world"
local Transform = require "squirtle.libs.geo.transform"
local Navigator = require "squirtle.libs.turtle.navigator"

local function printUsage()
    print("Usage:")
    print("goto <x> <y> <z>")
end

local function navigateTo(target, world)
    print("navigate to", target)
    local facing, location = Turtle.orientate()

    return Navigator.navigateTo(location, facing, target, world, function(block)
        return block.name == "minecraft:stone"
    end)
end

local function main(args)
    print("[goto @ 1.0.0]")

    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])

    if x == nil or y == nil or z == nil then
        return printUsage()
    end

    local target = Vector.new(x, y, z)
    local startX, startY, startZ = gps.locate()
    local start = Vector.new(startX, startY, startZ)
    -- local world = {}
    -- local world = World.new(Transform.new(start))
    local world = World.new(Transform.new(start), 16, 1, 16)

    while true do
        local reachedGoal, msg = navigateTo(target, world)

        if not reachedGoal then
            return false, msg
        end

        print("reached goal!")
        print("going to start in 3s...")
        os.sleep(3)

        local reachedStart, msg = navigateTo(start, world)

        if not reachedStart then
            return false, msg
        end

        print("reached start!")
        print("going to goal in 3s...")
        os.sleep(3)
    end
end

return main(arg)
