package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Vectors = require "elements.vector"
local Side = require "elements.vector"
local World = require "scout.world"
local Transform = require "scout.transform"
local inspect = require "squirtle.inspect"
local navigate = require "squirtle.navigate"
local orientate = require "squirtle.orientate"

local function isHome()
    local inspected = inspect(Side.bottom)

    return inspected and inspected.name == "minecraft:barrel"
end

---@param point Vector
---@param world World
---@param start Vector
local function nextPoint(point, world, start)
    local delta = Vectors.new(0, 0, 0)
    local worldPos = world.transform.position

    if start.x == worldPos.x then
        delta.x = 1
    elseif start.x == worldPos.x + world.width - 1 then
        delta.x = -1
    end

    if start.z == worldPos.z then
        delta.z = 1
    elseif start.z == worldPos.z + world.depth - 1 then
        delta.z = -1
    end

    if start.y == worldPos.y then
        delta.y = 1
    elseif start.y == worldPos.y + world.height - 1 then
        delta.y = -1
    end

    local relative = Vectors.minus(point, start)

    if relative.z % 2 == 1 then
        delta.x = delta.x * -1
    end

    if relative.y % 2 == 1 then
        delta.x = delta.x * -1
        delta.z = delta.z * -1
    end

    if world:isInBoundsX(point.x + delta.x) then
        return Vectors.plus(point, Vectors.new(delta.x, 0, 0))
    elseif world:isInBoundsZ(point.z + delta.z) then
        return Vectors.plus(point, Vectors.new(0, 0, delta.z))
    elseif world:isInBoundsY(point.y + delta.y) then
        return Vectors.plus(point, Vectors.new(0, delta.y, 0))
    else
        Utils.prettyPrint(delta)
        print("reached the end")
        return false -- reached the end
    end
end

local function isBreakable(block)
    return not string.find(block.name, "ore")
end

---@param home Vector
---@param world World
---@return Vector
local function determineStart(home, world)

    local corners = {
        Vectors.new(world.x, world.y, world.z),
        Vectors.new(world.x + world.width - 1, world.y, world.z),
        Vectors.new(world.x, world.y + world.height - 1, world.z),
        Vectors.new(world.x + world.width - 1, world.y + world.height - 1, world.z),
        --
        Vectors.new(world.x, world.y, world.z + world.depth - 1),
        Vectors.new(world.x + world.width - 1, world.y, world.z + world.depth - 1),
        Vectors.new(world.x, world.y + world.height - 1, world.z + world.depth - 1),
        Vectors.new(world.x + world.width - 1, world.y + world.height - 1, world.z + world.depth - 1)
    }

    ---@type Vector
    local best

    for i = 1, #corners do
        if best == nil or Vectors.length(best - home) > Vectors.length(corners[i] - home) then
            best = corners[i]
        end
    end

    return best
end

local function main(args)
    -- if not isHome() then
    --     error("expected to be home")
    -- end

    local home, facing = orientate()
    -- local world = World.new(Transform.new(position + Vectors.new(7, 0, 7)), 6, 3, 4)
    local world = World.new(Transform.new(Vectors.new(-11, 200, 19)), 6, 7, 5)
    local start = determineStart(home, world)
    Utils.prettyPrint(nextPoint(start, world, start))

    if not navigate(start) then
        error("path to entry must be free")
    end

    local point = start

    while point do
        local moved, msg = navigate(point, world, isBreakable)

        if not moved then
            print(msg)
        end

        
        point = nextPoint(point, world, start)
        Utils.prettyPrint(point)
    end

    print("all done! going home...")
    navigate(home, world, isBreakable)
    print("done & home <3")
end

main(arg)
