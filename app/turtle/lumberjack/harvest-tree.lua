local Squirtle = require "squirtle"

local function digLeftAndRight()
    Squirtle.turn("left")
    Squirtle.mine()
    Squirtle.suck()
    Squirtle.turn("back")
    Squirtle.mine()
    Squirtle.suck()
    Squirtle.turn("left")
end

local function digUpAndDown()
    Squirtle.dig("up")
    Squirtle.dig("down")
end

local function digSuckMove()
    Squirtle.mine()
    Squirtle.suck()
    Squirtle.move()
end

local function moveOutAndCutLeaves(leftAndRightOnFirstStep)
    leftAndRightOnFirstStep = leftAndRightOnFirstStep or false
    digSuckMove()
    digUpAndDown()

    if leftAndRightOnFirstStep then
        digLeftAndRight()
    end

    digSuckMove()
    digUpAndDown()
    digLeftAndRight()
    Squirtle.walk("back", 2)
end

local function digAllSides()
    for _ = 1, 4 do
        Squirtle.mine()
        Squirtle.turn("left")
    end
end

---@param minSaplings integer
local function collectSaplings(minSaplings)
    if not Squirtle.has("minecraft:birch_sapling", minSaplings) then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            Squirtle.turn("left")
        end
    end
end

---@param minSaplings? integer
return function(minSaplings)
    minSaplings = minSaplings or 32

    while Squirtle.probe("top", "minecraft:birch_log") do
        Squirtle.walk("up")

        if Squirtle.probe("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    Squirtle.walk("up") -- goto peak
    digAllSides() -- dig peak
    Squirtle.walk("down", 2)
    collectSaplings(minSaplings)
    Squirtle.walk("down")
    collectSaplings(minSaplings)

    while Squirtle.tryWalk("down") do
    end
end
