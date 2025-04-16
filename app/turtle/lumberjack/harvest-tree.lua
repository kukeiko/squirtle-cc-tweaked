local TurtleApi = require "lib.apis.turtle.turtle-api"

local function digLeftAndRight()
    TurtleApi.turn("left")
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.turn("right")
    TurtleApi.turn("right")
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.turn("left")
end

local function digUpAndDown()
    TurtleApi.dig("up")
    TurtleApi.dig("down")
end

local function digSuckMove()
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.move()
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
    TurtleApi.walk("back", 2)
end

local function digAllSides()
    for _ = 1, 4 do
        TurtleApi.tryMine()
        TurtleApi.turn("left")
    end
end

---@param minSaplings integer
local function collectSaplings(minSaplings)
    if not TurtleApi.has("minecraft:birch_sapling", minSaplings) then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            TurtleApi.turn("left")
        end
    end
end

---@param minSaplings? integer
return function(minSaplings)
    minSaplings = minSaplings or 32

    while TurtleApi.probe("top", "minecraft:birch_log") do
        TurtleApi.move("up")

        if TurtleApi.probe("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    TurtleApi.move("up") -- goto peak
    digAllSides() -- dig peak
    TurtleApi.move("down", 2)
    collectSaplings(minSaplings)
    TurtleApi.move("down")
    collectSaplings(minSaplings)

    while TurtleApi.tryWalk("down") do
    end
end
