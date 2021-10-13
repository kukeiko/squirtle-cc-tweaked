local Cardinal = require "squirtle.libs.cardinal"
local Side = require "squirtle.libs.side"
local Turtle = require "squirtle.libs.turtle"
local PathFinding = require "squirtle.libs.path-finding"

local Navigator = {}

---@class NavigatorMoveOptions
---@field attack? boolean
---@field dig? boolean|function

---@param side integer
---@param length integer
---@param options NavigatorMoveOptions
local function move(side, length, options)
    if not Turtle.hasFuel(length) then
        return false, string.format("not enough fuel to move %d times", length)
    end

    for _ = 1, length do
        while not Turtle.move(side) do
            local block = Turtle.inspectAt(side)

            if not block and options.attack then
                print("trying to attack - not implemented yet :c")
                os.sleep(1)
            elseif not block and not options.attack then
                print("something is blocking me, sleeping 1s...")
                os.sleep(1)
            elseif block and (options.dig == true or options.dig(block, side)) then
                Turtle.digAt(side)
            elseif block and (options.dig == false or options.dig(block, side) == false) then
                return false
            end
        end
    end
end

---@param location Vector
---@param facing integer
---@param path Vector[]
---@param options? NavigatorMoveOptions
function Navigator.walkPath(location, facing, path, options)
    if #path == 0 then
        return true, location, facing
    end
end

---@param start Vector
---@param facing integer
---@param goal Vector
---@param world World
---@param breakable? function
function Navigator.navigateTo(start, facing, goal, world, breakable)
    breakable = breakable or function()
        return false
    end

    while true do
        local path, msg = PathFinding.findPath(world, start, goal, facing)

        if not path then
            return false, facing, start, msg
        end

        local success, newLocation, newFacing, failedSide =
            Turtle.tryWalkPathPeaceful(path, start, facing)

        if success then
            print("success!")
            return true, newFacing, newLocation
        else
            start = newLocation
            facing = newFacing

            print(string.format("hit a block @ %s, scanning...", Side.getName(failedSide)))
            local block = Turtle.getBlockAt(failedSide)
            local scannedLocation = start + Cardinal.toVector(Cardinal.fromSide(failedSide, facing))

            if block and breakable(block) then
                Turtle.digAt(failedSide)
            elseif block then
                world:setBlock(scannedLocation)
            else
                error("could not move, not sure why")
                -- return false, "could not move, not sure why"
            end
        end
    end
end

---@param target Vector
---@param location Vector
---@param facing integer
---@param options? NavigatorMoveOptions
function Navigator.moveTo(target, location, facing, options)
    local delta = target:minus(location)

    if delta.y > 0 then
        move(Side.top, delta.y, options)
    elseif delta.y < 0 then
        move(Side.bottom, -delta.y, options)
    end

    if delta.x > 0 then
        facing = Turtle.turnToCardinal(facing, Cardinal.east)
        move(Side.front, delta.x, options)
    elseif delta.x < 0 then
        facing = Turtle.turnToCardinal(facing, Cardinal.west)
        move(Side.front, -delta.x, options)
    end

    if delta.z > 0 then
        facing = Turtle.turnToCardinal(facing, Cardinal.south)
        move(Side.front, delta.z, options)
    elseif delta.z < 0 then
        facing = Turtle.turnToCardinal(facing, Cardinal.north)
        move(Side.front, -delta.z, options)
    end
end

return Navigator
