local Side = require "elements.side"
local Backpack = require "squirtle.backpack"
local dig = require "squirtle.dig"
local move = require "squirtle.move"
local inspect = require "squirtle.inspect"
local turn = require "squirtle.turn"
local suck = require "squirtle.suck"

local function digLeftAndRight()
    turn(Side.left)
    dig()
    suck()
    turn(Side.back)
    dig()
    suck()
    turn(Side.left)
end

local function digUpAndDown()
    dig(Side.top)
    dig(Side.bottom)
end

---@param side? integer
local function digAndMove(side)
    side = side or Side.front
    dig(side)
    suck()
    move(side)
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
    move(Side.back)
    move(Side.back)
end

local function digAllSides()
    for _ = 1, 4 do
        dig()
        turn(Side.left)
    end
end

return function()
    while inspect(Side.top, "minecraft:birch_log") do
        dig(Side.top)
        move(Side.top)

        if inspect(Side.front, "minecraft:birch_leaves") then
            digAllSides()
        end
    end

    digAndMove(Side.top) -- goto peak
    digAllSides() -- dig peak
    move(Side.bottom)
    move(Side.bottom)

    if Backpack.getItemStock("minecraft:birch_sapling") < 32 then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            turn()
        end
    end

    move(Side.bottom)

    if Backpack.getItemStock("minecraft:birch_sapling") < 32 then
        for i = 1, 4 do
            moveOutAndCutLeaves(i % 2 == 1)
            turn()
        end
    end

    while move(Side.bottom) do
    end
end
