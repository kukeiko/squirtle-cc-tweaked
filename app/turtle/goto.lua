package.path = package.path .. ";/lib/?.lua"

local Vector = require "elements.vector"
local World = require "scout.world"
local Transform = require "scout.transform"
local navigate = require "squirtle.navigate"

local function printUsage()
    print("Usage:")
    print("goto <x> <y> <z>")
end

local function main(args)
    print("[goto @ 1.0.0]")

    local x = tonumber(args[1])
    local y = tonumber(args[2])
    local z = tonumber(args[3])

    if x == nil or y == nil or z == nil then
        return printUsage()
    end

    local goal = Vector.new(x, y, z)
    local startX, startY, startZ = gps.locate()
    local start = Vector.new(startX, startY, startZ)
    -- local world = {}
    local world = World.new(Transform.new(start))
    -- local world = World.new(Transform.new(start), 16, 1, 16)

    while true do
        local reachedGoal, msg = navigate(goal, world, function(block)
            return block.name == "minecraft:stone"
        end)

        if not reachedGoal then
            return false, msg
        end

        print("reached goal!")
        print("going to start in 3s...")
        os.sleep(3)

        local reachedStart, msg = navigate(start, world, function(block)
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
