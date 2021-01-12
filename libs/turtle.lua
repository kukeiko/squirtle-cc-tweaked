if not turtle then
    error("not a Turtle")
end

package.path = package.path .. ";/libs/?.lua"

local Sides = require "sides"

local native = turtle
local noop = function()
end

local Turtle = {}

setmetatable(Turtle, {__index = native})

function Turtle.turn(side)
    if side == "left" then
        return native.turnLeft()
    elseif side == "right" then
        return native.turnRight()
    elseif side == "back" then
        return Turtle.turnAround()
    else
        error("Can only turn left, right and back")
    end
end

function Turtle.turnAround()
    local s, e = native.turnLeft()

    if not s then
        return e
    end

    return native.turnLeft()
end

function Turtle.faceSide(side)
    if side == "left" or side == "right" or side == "back" then
        Turtle.turn(side)

        return "front", function()
            if side == "left" then
                return native.turnRight()
            elseif side == "right" then
                return native.turnLeft()
            elseif side == "back" then
                return Turtle.turnAround()
            end
        end
    end

    return side, noop
end

function Turtle.suckAll(side)
    local suckSide, undoFaceBuffer = Turtle.faceSide(side)

    while Turtle.suck(suckSide) do
    end

    undoFaceBuffer()
end

function Turtle.turnToHaveSideAt(side, at)
    if side == at then
        return true
    end

    if Sides.invert(side) == at then
        return Turtle.turnAround()
    end

    -- [todo] there should be an easier way than bruteforcing
    if side == "front" then
        return Turtle.turn(Sides.invert(at))
    elseif side == "back" then
        return Turtle.turn(at)
    elseif side == "left" and at == "front" then
        return native.turnLeft()
    elseif side == "left" and at == "back" then
        return native.turnRight()
    elseif side == "right" and at == "front" then
        return native.turnRight()
    elseif side == "right" and at == "back" then
        return native.turnLeft()
    end

    return false
end

function Turtle.forwardUntilBlocked()
    while native.forward() do end
end

function Turtle.suck(side, count)
    if side == "top" then
        return native.suckUp(count)
    elseif side == "bottom" then
        return native.suckDown(count)
    elseif side == "front" or side == nil then
        return native.suck(count)
    else
        error("Can only suck from front, top or bottom")
    end
end

function Turtle.drop(side, count)
    if side == "top" then
        return native.dropUp(count)
    elseif side == "bottom" then
        return native.dropDown(count)
    elseif side == "front" or side == nil then
        return native.drop(count)
    else
        error("Can only drop in front, top or bottom")
    end
end

function Turtle.inspect(side)
    local inspectFn

    if side == "front" or side == nil then
        inspectFn = native.inspect
    elseif side == "top" then
        inspectFn = native.inspectUp
    elseif side == "bottom" then
        inspectFn = native.inspectDown
    else
        error("can only inspect front, top or bottom")
    end

    local success, inspected = inspectFn()

    if success then
        return inspected
    end
end

function Turtle.inspectName(side)
    local inspected = Turtle.inspect(side)

    if inspected then
        return inspected.name
    end
end

function Turtle.inspectUpAndDown()
    local _, up = native.inspectUp()
    local _, down = native.inspectDown()

    return up, down
end

function Turtle.inspectNameDownOrUp()
    local _, down = native.inspectDown()

    if down then
        return down.name, "bottom"
    else
        local _, up = native.inspectUp()

        if up then
            return up.name, "top"
        end
    end
end

function Turtle.getMissingFuel()
    local fuelLevel = native.getFuelLevel()

    if fuelLevel == "unlimited" then
        return 0
    end

    return native.getFuelLimit() - native.getFuelLevel()
end

function Turtle.hasFuel(level)
    local fuelLevel = native.getFuelLevel()

    return fuelLevel == "unlimited" or fuelLevel >= level
end

function Turtle.faceFirstBlock(sides)
    sides = sides or Sides.all()

    for i = 1, #sides do
        local side = sides[i]
        local inspectSide, undoFaceSide = Turtle.faceSide(side)
        local inspected = Turtle.inspect(inspectSide)

        if not inspected then
            undoFaceSide()
        else
            return inspected, side
        end
    end
end

return Turtle
