local Squirtle = require "lib.squirtle.squirtle-api"

local function digLeftAndRight()
    Squirtle.turn("left")
    Squirtle.tryMine()
    Squirtle.suck()
    Squirtle.turn("right")
    Squirtle.turn("right")
    Squirtle.tryMine()
    Squirtle.suck()
    Squirtle.turn("left")
end

local function digUpAndDown()
    Squirtle.dig("up")
    Squirtle.dig("down")
end

local function digSuckMove()
    Squirtle.tryMine()
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
        Squirtle.tryMine()
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
        Squirtle.move("up")

        if Squirtle.probe("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    Squirtle.move("up") -- goto peak
    digAllSides() -- dig peak
    Squirtle.move("down", 2)
    collectSaplings(minSaplings)
    Squirtle.move("down")
    collectSaplings(minSaplings)

    while Squirtle.tryWalk("down") do
    end
end
