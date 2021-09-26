package.path = package.path .. ";/libs/?.lua"

local Turtle = require "turtle"

local Navigator = {}

function Navigator.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if Turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and Turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and Turtle.down() then
            strategy = "down"
            forbidden = "up"
        elseif Turtle.turnLeft() and Turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif Turtle.turnLeft() and forbidden ~= "back" and Turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif Turtle.turnLeft() and Turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while Turtle.forward() do
            end
        elseif strategy == "up" then
            while Turtle.up() do
            end
        elseif strategy == "down" then
            while Turtle.down() do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

return Navigator
