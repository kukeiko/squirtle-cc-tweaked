package.path = package.path .. ";/lib/?.lua"

local Vector = require "elements.vector"
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
local function nextPoint(point, world)
    local relative = point:minus(world.transform.position)

    if relative.z % 2 == 0 then
        if relative.x + 1 < world.width then
            return point + Vector.new(1, 0, 0)
        elseif relative.z + 1 < world.depth then
            return point + Vector.new(0, 0, 1)
        else
            return false
        end
    else
        if relative.x - 1 >= 0 then
            return point + Vector.new(-1, 0, 0)
        elseif relative.z + 1 < world.depth then
            return point + Vector.new(0, 0, 1)
        else
            return false
        end
    end
end

local function breakable(block)
    return not string.find(block.name, "ore")
end

---@param layer integer
---@param world World
local function moveToLayer(layer, world)
    local goal = world.transform.position:plus(Vector.new(0, layer, 0))

    while goal do
        if navigate(goal, world, breakable) then
            return true
        end

        goal = nextPoint(goal, world)
    end

    error(string.format("no entry to layer %d found", layer))
end

---@param layer integer
---@param world World
local function exposeLayer(layer, world)
    local goal = world.transform.position:plus(Vector.new(0, layer, 0))

    while goal do
        navigate(goal, world, breakable)
        goal = nextPoint(goal, world)
    end
end

local function main(args)
    if not isHome() then
        error("expected to be home")
    end

    local position, facing = orientate()
    local world = World.new(Transform.new(position), 3, 2, 3)
    local layer = 0

    while layer < world.height do
        moveToLayer(layer, world)
        exposeLayer(layer, world)
        layer = layer + 1
    end

    navigate(world.transform.position, world, breakable)
    print("all done!")
end

main(arg)
