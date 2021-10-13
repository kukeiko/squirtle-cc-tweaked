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
    local home = position:asChunkOrigin()
    -- local home = Vector.new(home.x * 16, position.y, home.z * 16)

    ---@type ExposeOresAppState
    local state = {home = home, checkpoint = home:copy()}

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

local function sameLayerLoop()
end

---@param state ExposeOresAppState
local function loop(state)
    print("[tick]")
    print("home:", state.home)
    local facing, position = Turtle.orientate()
    local world = World.new(Transform.new(state.home), 2, 1, 2)

    if position.y ~= state.checkpoint.y then
        return false, "moving to different layer not supported yet"
    else
        local lastGoal = position

        while true do
            local goal = nextPoint(lastGoal, world)
            print("next point:", goal)

            if goal:equals(lastGoal) then
                print("reached last block!")
                return true
            end

            local navSuccess, newFacing, newLocation, msg =
                Navigator.navigateTo(position, facing, goal, world, function(block)
                    return not string.find(block.name, "ore")
                end)

            facing = newFacing
            position = newLocation
            lastGoal = goal

            if not navSuccess then
                print("hit an unbreakable block, finding next point...")
            end
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
