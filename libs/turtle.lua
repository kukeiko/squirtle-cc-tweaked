package.path = package.path .. ";/libs/?.lua"

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

function Turtle.getMissingFuel()
    local fuelLevel = turtle.getFuelLevel()

    if fuelLevel == "unlimited" then
        return 0
    end

    return turtle.getFuelLimit() - turtle.getFuelLevel()
end

return Turtle
