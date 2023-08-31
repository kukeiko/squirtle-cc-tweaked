local SquirtleV2 = require "squirtle.squirtle-v2"

local function digLeftAndRight()
    SquirtleV2.left()
    SquirtleV2.dig()
    SquirtleV2.suck()
    SquirtleV2.around()
    SquirtleV2.dig()
    SquirtleV2.suck()
    SquirtleV2.left()
end

local function digUpAndDown()
    SquirtleV2.digUp()
    SquirtleV2.digDown()
end

local function digSuckMove()
    SquirtleV2.dig()
    SquirtleV2.suck()
    SquirtleV2.move()
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
    SquirtleV2.back(2)
end

local function digAllSides()
    for _ = 1, 4 do
        SquirtleV2.dig()
        SquirtleV2.left()
    end
end

---@param minSaplings integer
local function collectSaplings(minSaplings)
    if not SquirtleV2.has("minecraft:birch_sapling", minSaplings) then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            SquirtleV2.left()
        end
    end
end

---@param minSaplings? integer
return function(minSaplings)
    minSaplings = minSaplings or 32

    while SquirtleV2.inspect("top", "minecraft:birch_log") do
        SquirtleV2.up()

        if SquirtleV2.inspect("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    SquirtleV2.up() -- goto peak
    digAllSides() -- dig peak
    SquirtleV2.down(2)
    collectSaplings(minSaplings)
    SquirtleV2.down()
    collectSaplings(minSaplings)

    while SquirtleV2.tryDown() do
    end
end
