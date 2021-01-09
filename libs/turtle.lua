if not turtle then
    error("not a Turtle")
end

package.path = package.path .. ";/libs/?.lua"

local Sides = require "sides"
local noop = function()
end

local Turtle = {}

setmetatable(Turtle, {__index = turtle})

function Turtle.turn(side)
    if side == "left" then
        return turtle.turnLeft()
    elseif side == "right" then
        return turtle.turnRight()
    elseif side == "back" then
        return Turtle.turnAround()
    else
        error("Can only turn left, right and back")
    end
end

function Turtle.turnAround()
    local s, e = turtle.turnLeft()

    if not s then
        return e
    end

    return turtle.turnLeft()
end

function Turtle.faceSide(side)
    if side == "left" or side == "right" or side == "back" then
        Turtle.turn(side)

        return "front", function()
            if side == "left" then
                return turtle.turnRight()
            elseif side == "right" then
                return turtle.turnLeft()
            elseif side == "back" then
                return Turtle.turnAround()
            end
        end
    end

    return side, noop
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
        return Turtle.turnLeft()
    elseif side == "left" and at == "back" then
        return Turtle.turnRight()
    elseif side == "right" and at == "front" then
        return Turtle.turnRight()
    elseif side == "right" and at == "back" then
        return Turtle.turnLeft()
    end

    return false
end

function Turtle.suck(side, count)
    if side == "top" then
        return turtle.suckUp(count)
    elseif side == "bottom" then
        return turtle.suckDown(count)
    elseif side == "front" or side == nil then
        return turtle.suck(count)
    else
        error("Can only suck from front, top or bottom")
    end
end

function Turtle.drop(side, count)
    if (side == "top") then
        return turtle.dropUp(count)
    elseif (side == "bottom") then
        return turtle.dropDown(count)
    elseif side == "front" or side == nil then
        return turtle.drop(count)
    else
        error("Can only drop in front, top or bottom")
    end
end

function Turtle.inspectName(side)
    side = side or "front"
    local inspectFn

    if side == "front" then
        inspectFn = Turtle.inspect
    elseif side == "top" then
        inspectFn = Turtle.inspectUp
    elseif side == "bottom" then
        inspectFn = Turtle.inspectDown
    else
        error("can only inspect in front, top or bottom")
    end

    local success, inspected = inspectFn()

    if not success then
        return success, inspected
    end

    return inspected.name
end

function Turtle.inspectUpAndDown()
    local _, up = Turtle.inspectUp()
    local _, down = Turtle.inspectDown()

    return up, down
end

function Turtle.inspectNameDownOrUp()
    local _, down = Turtle.inspectDown()

    if down then
        return down.name, "bottom"
    else
        local _, up = Turtle.inspectUp()

        if up then
            return up.name, "top"
        end
    end
end

function Turtle.getMissingFuel()
    local fuelLevel = turtle.getFuelLevel()

    if fuelLevel == "unlimited" then
        return 0
    end

    return turtle.getFuelLimit() - turtle.getFuelLevel()
end

function Turtle.hasFuel(level)
    local fuelLevel = turtle.getFuelLevel()

    return fuelLevel == "unlimited" or fuelLevel >= level
end

return Turtle
