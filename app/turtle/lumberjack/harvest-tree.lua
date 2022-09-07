local Backpack = require "squirtle.backpack"
local dig = require "squirtle.dig"
local move = require "squirtle.move"
local inspect = require "squirtle.inspect"
local turn = require "squirtle.turn"
local suck = require "squirtle.suck"

local function digLeftAndRight()
    turn("left")
    dig()
    suck()
    turn("back")
    dig()
    suck()
    turn("left")
end

local function digUpAndDown()
    dig("top")
    dig("bottom")
end

---@param direction? string
local function digAndMove(direction)
    direction = direction or "front"
    dig(direction)
    suck()
    move(direction)
end

local function moveOutAndCutLeaves(leftAndRightOnFirstStep)
    leftAndRightOnFirstStep = leftAndRightOnFirstStep or false
    digAndMove()
    digUpAndDown()

    if leftAndRightOnFirstStep then
        digLeftAndRight()
    end

    digAndMove()
    digUpAndDown()
    digLeftAndRight()
    move("back")
    move("back")
end

local function digAllSides()
    for _ = 1, 4 do
        dig()
        turn("left")
    end
end

---@param minSaplings? integer
return function(minSaplings)
    minSaplings = minSaplings or 32

    while inspect("top", "minecraft:birch_log") do
        dig("top")
        move("top")

        if inspect("front", "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    digAndMove("top") -- goto peak
    digAllSides() -- dig peak
    move("bottom")
    move("bottom")

    if Backpack.getItemStock("minecraft:birch_sapling") < minSaplings then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            turn()
        end
    end

    move("bottom")

    if Backpack.getItemStock("minecraft:birch_sapling") < minSaplings then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            turn()
        end
    end

    while move("bottom") do
    end
end
