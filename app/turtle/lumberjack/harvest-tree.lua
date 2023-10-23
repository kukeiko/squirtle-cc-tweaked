local Squirtle = require "squirtle"

local function digLeftAndRight()
    Squirtle.left()
    Squirtle.dig()
    Squirtle.suck()
    Squirtle.around()
    Squirtle.dig()
    Squirtle.suck()
    Squirtle.left()
end

local function digUpAndDown()
    Squirtle.digUp()
    Squirtle.digDown()
end

local function digSuckMove()
    Squirtle.dig()
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
    Squirtle.back(2)
end

local function digAllSides()
    for _ = 1, 4 do
        Squirtle.dig()
        Squirtle.left()
    end
end

---@param minSaplings integer
local function collectSaplings(minSaplings)
    if not Squirtle.has("minecraft:birch_sapling", minSaplings) then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            Squirtle.left()
        end
    end
end

---@param minSaplings? integer
return function(minSaplings)
    minSaplings = minSaplings or 32

    while Squirtle.inspect("top", "minecraft:birch_log") do
        Squirtle.up()

        if Squirtle.inspect("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    Squirtle.up() -- goto peak
    digAllSides() -- dig peak
    Squirtle.down(2)
    collectSaplings(minSaplings)
    Squirtle.down()
    collectSaplings(minSaplings)

    while Squirtle.tryDown() do
    end
end
