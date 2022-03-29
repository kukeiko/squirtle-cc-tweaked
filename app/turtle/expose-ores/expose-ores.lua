package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local Vectors = require "elements.vector"
local Side = require "elements.vector"
local World = require "scout.world"
local Chest = require "world.chest"
local Transform = require "scout.transform"
local inspect = require "squirtle.inspect"
local navigate = require "squirtle.navigate"
local orientate = require "squirtle.orientate"
local locate = require "squirtle.locate"
local setup = require "expose-ores.setup"

---@class ExposeOresAppState
---@field home Vector
---@field world World
---@field start Vector
---@field checkpoint Vector

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
    local isOre = string.find(block.name, "ore")
    local isChest = string.find(block.name, "chest")
    local isBarrel = string.find(block.name, "barrel")

    return not isOre and not isChest and not isBarrel
end

local function main(args)
    ---@type ExposeOresAppState
    local state = Utils.loadAppState("expose-ores", {})

    if not state.home then
        state = setup()
    end

    if not state.checkpoint then
        print("no checkpoint, assuming digging is finished, going home ...")
        navigate(state.home, nil, isBreakable)
        print("done & home <3")
        return
    end

    local position = locate()
    state.world = World.new(Transform.new(Vectors.new(state.world.x, state.world.y, state.world.z)), state.world.width,
                            state.world.height, state.world.depth)
    state.checkpoint = Vectors.cast(state.checkpoint)

    if not state.world:isInBounds(position) then
        print("not inside digging area, going there now...")
        navigate(state.checkpoint, nil, isBreakable)
        print("should be inside digging area again!")
    end

    local point = state.checkpoint
    local previous = point

    while point do
        if previous.y ~= point.y then
            print("saving checkpoint at", point)
            state.checkpoint = point
            Utils.saveAppState(state, "expose-ores")
        end

        local moved, msg = navigate(point, state.world, isBreakable)

        if not moved then
            print(msg)
        end

        previous = point
        point = nextPoint(point, state.world, state.start)
    end

    print("all done! going home...")
    state.checkpoint = nil
    Utils.saveAppState(state, "expose-ores")
    navigate(state.home)
    print("done & home <3")
end

main(arg)
