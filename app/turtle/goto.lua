if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local World = require "lib.models.world"
local Squirtle = require "lib.squirtle.squirtle-api"

local function printUsage()
    print("Usage:")
    print("goto <x> <y> <z>")
end

local function main(args)
    print(string.format("[goto %s] booting...", version()))

    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])

    if x == nil or y == nil or z == nil then
        return printUsage()
    end

    ---@type Vector
    local goal = {x = x, y = y, z = z}
    local start = Squirtle.locate()
    Squirtle.orientate()
    ---@type World
    local world = World.create(start.x, start.y, start.z)

    while true do
        local reachedGoal, msg = Squirtle.navigate(goal, world, function(block)
            return block.name == "minecraft:stone"
        end)

        if not reachedGoal then
            return false, msg
        end

        print("reached goal!")
        print("going to start in 3s...")
        os.sleep(3)

        local reachedStart, msg = Squirtle.navigate(start, world, function(block)
            return block.name == "minecraft:stone"
        end)

        if not reachedStart then
            return false, msg
        end

        print("reached start!")
        print("going to goal in 3s...")
        os.sleep(3)
    end
end

return main(arg)
