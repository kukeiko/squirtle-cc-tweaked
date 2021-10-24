package.path = package.path .. ";/?.lua"

local Utils = require "squirtle.libs.utils"
local Vector = require "squirtle.libs.vector"
local Turtle = require "squirtle.libs.turtle"
local Navigator = require "squirtle.libs.turtle.navigator"
local World = require "squirtle.libs.geo.world"
local Transform = require "squirtle.libs.geo.transform"

local appName = "expose-ores"
local appVersion = "1.0.0"

---@class ExposeOresAppState
---@field home Vector
---@field checkpoint Vector

local function loadState()
    ---@type ExposeOresAppState
    local state = Utils.loadAppState(appName)
    state.home = Utils.parseVector(state.home, "home")
    state.checkpoint = Utils.parseVector(state.checkpoint, "checkpoint")

    return state
end

local function setup()
    print("[setup]")
    local facing, position = Turtle.orientate()

    ---@type ExposeOresAppState
    local state = {home = position:copy(), checkpoint = position:copy()}

    Utils.saveAppState(state, appName)
    Utils.waitForUserToHitEnter()
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
            return point
        end
    else
        if relative.x - 1 >= 0 then
            return point + Vector.new(-1, 0, 0)
        elseif relative.z + 1 < world.depth then
            return point + Vector.new(0, 0, 1)
        else
            return point
        end
    end
end

local function breakable(block)
    return not string.find(block.name, "ore")
end

---@param world World
local function moveToLayerLoop(position, facing, world, layer)
    local goal = world.transform.position:plus(Vector.new(0, layer - 1, 0))
    local lastGoal = goal

    while true do
        local navSuccess, newFacing, newLocation, msg =
            Navigator.navigateTo(position, facing, goal, world, breakable)

        facing = newFacing
        position = newLocation
        lastGoal = goal

        if not navSuccess then
            goal = nextPoint(lastGoal, world)

            if goal:equals(lastGoal) then
                -- [todo] instead of erroring out, maybe just go home?
                -- and print that this layer is not reachable
                error(string.format("no entry to layer %d found", layer))
            end

            print("hit an unbreakable block, finding next point...")
        else
            return true, facing, position
        end
    end
end

---@param position Vector
---@param facing integer
---@param world World
local function exposeLayer(position, facing, world)
    local lastGoal = position

    while true do
        local goal = nextPoint(lastGoal, world)

        if goal:equals(lastGoal) then
            return true
        end

        local navSuccess, newFacing, newLocation, msg =
            Navigator.navigateTo(position, facing, goal, world, function(block)
                return not string.find(block.name, "ore")
            end)

        facing = newFacing
        position = newLocation
        lastGoal = goal
    end
end

---@param state ExposeOresAppState
local function loop(state)
    print("home:", state.home)
    local facing, position = Turtle.orientate()
    local world = World.new(Transform.new(state.home), 3, 3, 3)
    local layer = 1

    if position.y ~= state.checkpoint.y then
        return false, "moving to different layer not supported yet"
    else
        while true do
            print("exposing layer", layer)
            exposeLayer(position, facing, world)
            layer = layer + 1

            if layer > world.height then
                print("finished, goin' home!")
                facing, position = Turtle.orientate()
                Navigator.navigateTo(position, facing, state.home, world)
                return true
            end
            print("moving to layer", layer)
            -- [todo] update cached instead
            facing, position = Turtle.orientate()
            moveToLayerLoop(position, facing, world, layer)
            facing, position = Turtle.orientate()
        end
    end

    Utils.waitForUserToHitEnter()
end

---@param args table
local function main(args)
    Utils.printAppBootScreen(appName, appVersion, 0)

    while not Utils.hasAppState(appName) do
        setup()
    end

    local state = loadState()
    loop(state)
end

return main(arg)
