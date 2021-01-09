package.path = package.path .. ";/libs/?.lua"

local Peripheral = require "peripheral"
local Sides = require "sides"
local Turtle = require "turtle"

---@class Home
local Home = {
    verticalBlock = "quark:sturdy_stone",
    verticalSide = "bottom",
    horizontalBlock = "quark:sturdy_stone",
    horizontalSide = "front"
}

function Home.new(verticalBlock, verticalSide, horizontalBlock, horizontalSide)
    local instance = {
        verticalBlock = verticalBlock or Home.verticalBlock,
        verticalSide = verticalSide or Home.verticalSide,
        horizontalBlock = horizontalBlock or Home.horizontalBlock,
        horizontalSide = horizontalSide or Home.horizontalSide
    }

    setmetatable(instance, {__index = Home})

    return instance
end

function Home:isHome()
    return Turtle.inspectName(self.verticalSide) == self.verticalBlock
end

function Home:park()
    if not self:isHome() then
        error("not at home")
    end

    local peripheral, side = Peripheral.wrapOne({self.horizontalBlock}, Sides.horizontal())

    if peripheral then
        return Turtle.turnToHaveSideAt(side, self.horizontalSide)
    end

    if Turtle.inspectName() == self.horizontalBlock then
        return Turtle.turnToHaveSideAt("front", self.horizontalSide)
    elseif Turtle.turnLeft() and Turtle.inspectName() == self.horizontalBlock then
        return Turtle.turnToHaveSideAt("front", self.horizontalSide)
    elseif Turtle.turnLeft() and Turtle.inspectName() == self.horizontalBlock then
        return Turtle.turnToHaveSideAt("front", self.horizontalSide)
    elseif Turtle.turnLeft() and Turtle.inspectName() == self.horizontalBlock then
        return Turtle.turnToHaveSideAt("front", self.horizontalSide)
    end

    Turtle.turnLeft()

    error("should be at home, but i didn't find my look-at-block " .. self.horizontalBlock)
end

return Home
