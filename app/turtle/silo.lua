package.path = package.path .. ";/lib/?.lua"

local selectItem = require "squirtle.backpack.select-item"
local place = require "squirtle.place"
local move = require "squirtle.move"
local squirtleTurn = require "squirtle.turn"
local dig = require "squirtle.dig"

print("[silo v1.0.0] booting...")

-- required blocks (for 9x chest height)
-- (64 + 33)x smooth_stone
-- 37x oak_loag
-- 29x stripped_oak_log
-- 10x redstone_lamp
-- 19x chests
-- 10x hopper
-- 10x comparator
-- 22x repeater
-- 13x redstone
-- 1x redstone_torch

local dark = arg[2] == "dark"
local basalt = arg[2] == "basalt"

local function selectChest()
    return selectItem("minecraft:chest", true)
end

local function selectSupport()
    local item = "minecraft:oak_log"

    if dark then
        item = "minecraft:dark_oak_log"
    elseif basalt then
        item = "minecraft:polished_basalt"
    end

    return selectItem(item, true)
end

local function selectHopper()
    return selectItem("minecraft:hopper", true)
end

local function selectLamp()
    return selectItem("minecraft:redstone_lamp", true)
end

local function selectComparator()
    return selectItem("minecraft:comparator", true)
end

local function selectRepeater()
    return selectItem("minecraft:repeater", true)
end

local function selectRedstone()
    return selectItem("minecraft:redstone", true)
end

local function selectRedstonePlaceBlock()
    return selectItem("minecraft:smooth_stone", true)
end

local function selectBacksideBlock()
    local item = "minecraft:stripped_oak_log"

    if dark then
        item = "minecraft:stripped_dark_oak_log"
    elseif basalt then
        item = "minecraft:deepslate_tiles"
    end

    return selectItem(item, true)
end

local function selectRedstoneTorch()
    return selectItem("minecraft:redstone_torch", true)
end

---@param side string
local function turn(side)
    if arg[1] == "left" then
        if side == "right" then
            side = "left"
        elseif side == "left" then
            side = "right"
        end
    end

    return squirtleTurn(side)
end

-- starting at bottem left w/ lamp side to the right
if string.lower(arg[1]) == "right" then
    squirtleTurn("right")
    move("forward", 2)
    squirtleTurn("left")
elseif string.lower(arg[1]) == "left" then
    squirtleTurn("right")
    move("forward", 4)
    squirtleTurn("left")
else
    error("invalid args")
end

-- place center chests
for _ = 1, 9 do
    selectChest()
    place()
    move("up")
end

-- place left support beam
move("forward")
turn("right")
move("back", 2)

selectSupport()
place("top")

move("down")
selectSupport()
place("top")

-- place left hoppers
for _ = 1, 4 do
    move("down")
    selectSupport()
    place("top")
    selectHopper()
    place()
    move("down")
    selectSupport()
    place("top")
end

-- floor layer
dig("down")
move("down")
selectSupport()
place("top")
turn("right")
dig()
move()
move("up")

-- right support
turn("left")
move("forward", 4)
turn("left")
move()
turn("left")

for _ = 1, 4 do
    selectHopper()
    place()
    move("up")
    selectSupport()
    place("down")
    move("up")
    selectSupport()
    place("down")
end

for i = 1, 2 do
    move("up")
    selectSupport()
    place("down")
end

-- build top support
move("forward", 2)

for i = 1, 5 do
    selectSupport()
    place()

    if i ~= 5 then
        move("back")
    end
end

-- build right support incl. lights
for i = 1, 10 do
    move("down")
    selectSupport()
    place("top")
    selectLamp()
    place()
end

-- bottom piece of right support
dig("down")
move("down")
selectSupport()
place("top")
turn("left")
dig()
move()
move("up")

-- place remaining chests
turn("right")
move("forward", 3)
turn("right")

for i = 1, 4 do
    move("up")
    selectChest()
    place()
    move("up")
end

turn("left")
move("forward", 2)
turn("right")

for i = 1, 5 do
    selectChest()
    place()

    if i ~= 5 then
        move("down", 2)
    end
end

-- move to backside
turn("left")
move()
move("down")
turn("right")
move()
dig()
move()
move("up")
turn("left")
move("back", 2)

local function placeBacksideBlocks()
    selectRedstonePlaceBlock()
    place("down")
    turn("right")
    move()
    selectRedstonePlaceBlock()
    place("down")
    move("back")
    turn("left")
    move()
    selectBacksideBlock()
    place("down")
    move()
    selectBacksideBlock()
    place("down")
    move()
    selectBacksideBlock()
    place("down")
    move("back")
end

for i = 1, 9 do
    if i % 2 == 1 then
        turn("right")
        move("forward")

        dig("down")
        selectRedstonePlaceBlock()
        place("down")
        move("up")

        selectComparator()
        place("down")
        move()
        selectRedstonePlaceBlock()
        place("down")
        turn("right")
        move()

        if i == 1 then
            move("down")
            dig("down")
            selectRedstonePlaceBlock()
            place("down")
            move("up")
        end

        selectRepeater()
        place("down")
        move()
        selectRedstonePlaceBlock()
        place("down")
        move()

        if i == 1 then
            move("down")
            dig("down")
            selectRedstonePlaceBlock()
            place("down")
            move("up")
        end

        selectRepeater()
        place("down")
        move()
        selectRedstonePlaceBlock()
        place("down")
        turn("right")
        move()

        move("down")
        if i == 1 then
            dig("down")
        end
        selectRedstonePlaceBlock()
        place("down")
        move("up")

        selectRedstone()
        place("down")
        move()

        move("down")
        if i == 1 then
            dig("down")
        end
        selectRedstonePlaceBlock()
        place("down")
        move("up")

        selectRedstone()
        place("down")
        turn("right")
        move("forward", 2)

        placeBacksideBlocks()
    else
        move("back")
        turn("right")
        move()
        selectRedstonePlaceBlock()
        place("down")
        move("up")
        selectComparator()
        place("down")
        move()
        selectRedstonePlaceBlock()
        place("down")
        turn("right")
        move()
        selectRepeater()
        place("down")
        move()
        selectRedstonePlaceBlock()
        place("down")
        turn("right")
        move()
        move("down")
        selectRedstonePlaceBlock()
        place("down")
        move("up")
        selectRepeater()
        place("down")
        move()
        move("down")
        selectRedstonePlaceBlock()
        place("down")
        move("up")
        selectRedstonePlaceBlock()
        place("down")
        turn("right")
        move()
        placeBacksideBlocks()
    end
end

-- build input chest

move()
turn("left")
move("back")
move("down")
dig()
selectHopper()
place()
turn("right")
move("forward", 2)
turn("left")
move()
turn("left")
selectHopper()
place()

-- redstone torch
move("down")
move()
turn("left")
selectRedstonePlaceBlock()
place()
move("down")
selectRedstoneTorch()
place("up")

-- "plus" construct
move("forward", 2)
move("up")
selectRedstonePlaceBlock()
place("down")
turn("back")

move("up")
selectRepeater()
place("down")

move("back")
selectRedstonePlaceBlock()
place("down")
move("up")
selectRedstone()
place("down")

for _ = 1, 2 do
    move()
    selectRedstonePlaceBlock()
    place("down")
end

turn("back")
move("up")
selectComparator()
place("down")

move()
selectRedstone()
place("down")

turn("right")
move()
move("down")
selectRedstonePlaceBlock()
place("down")

move("up")
selectRedstone()
place("down")

move()
-- move("down")
-- selectRedstonePlaceBlock()
-- place("down")
-- move("up")
selectRepeater()
place("down")

move()
selectRedstonePlaceBlock()
place("down")

move()
selectRepeater()
place("down")

move()
selectRedstonePlaceBlock()
place("down")

turn("right")
move()
move("down")
selectRedstonePlaceBlock()
place("down")
move("up")
selectRepeater()
place("down")
move()
move("down")
selectRedstonePlaceBlock()
place("down")
move("up")
selectRedstonePlaceBlock()
place("down")

-- last row of chest backing blocks + input chest
turn("right")
move()
placeBacksideBlocks()
move("forward", 2)
turn("left")
selectChest()
place("down")

-- go back home while placing last column of filler blocks
move("back")
turn("left")
move()

move("down")

for _ = 1, 9 do
    move("down")
    selectRedstonePlaceBlock()
    place("top")
end

move("back")
selectRedstonePlaceBlock()
place()
turn("right")
move()
move("down")
move("forward", 2)
move("up")

-- done!
if arg[1] == "right" then
    turn("back")
else
    squirtleTurn("right")
    move("forward", 6)
    squirtleTurn("right")
end
