package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local selectItem = require "squirtle.backpack.select-item"
local squirtlePlace = require "squirtle.place"
local move = require "squirtle.move"
local squirtleTurn = require "squirtle.turn"
local dig = require "squirtle.dig"
local Side = require "elements.side"
local boot = require "silo.boot"
local sequence = require "silo.sequence"

print("[silo v1.2.0] booting...")
local state = boot(arg)

if not state then
    return nil
end

---@param block string
---@param side? string
---@param offset? integer
local function place(block, side, offset)
    if offset then
        move(side, offset)
    end

    selectItem(block, true)
    squirtlePlace(side)

    if offset then
        move(Side.rotateAround(side or "forward"), offset)
    end
end

---@param side string
local function turn(side)
    if state.lampLocation == "left" then
        if side == "right" then
            side = "left"
        elseif side == "left" then
            side = "right"
        end
    end

    return squirtleTurn(side)
end

---@param times? integer
local function forward(times)
    move("forward", times)
end

---@param times? integer
local function up(times)
    move("up", times)
end

---@param times? integer
local function down(times)
    move("down", times)
end

---@param times? integer
local function back(times)
    move("back", times)
end

local function left()
    turn("left")
end

local function right()
    turn("right")
end

local function around()
    turn("back")
end

-- starting at bottem left w/ lamp side to the right
if state.lampLocation == "right" then
    squirtleTurn("right")
    move("forward", 2)
    squirtleTurn("left")
elseif state.lampLocation == "left" then
    squirtleTurn("right")
    move("forward", 4)
    squirtleTurn("left")
else
    error("invalid args")
end
------------------------------
-- place center chests
for _ = 1, (state.layers * 2) + 1 do
    place(state.blocks.chest)
    up()
end

-- place left support beam
forward()
right()
back(2)
place(state.blocks.support, "top")
down()
place(state.blocks.support, "top")

-- place left hoppers
for _ = 1, state.layers do
    down()
    place(state.blocks.support, "top")
    place(state.blocks.hopper)
    down()
    place(state.blocks.support, "top")
end

-- place bottom support beam
dig("down")
down()
place(state.blocks.support, "top")
right()
dig()
forward()
up()

-- right support
left()
forward(4)
left()
forward()
left()

for _ = 1, state.layers do
    place(state.blocks.hopper)
    up()
    place(state.blocks.support, "down")
    up()
    place(state.blocks.support, "down")
end

for _ = 1, 2 do
    up()
    place(state.blocks.support, "down")
end

-- build top support
forward(2)

for i = 1, 5 do
    place(state.blocks.support)

    if i ~= 5 then
        back()
    end
end

-- build right support incl. lights
for _ = 1, (state.layers * 2) + 2 do
    down()
    place(state.blocks.support, "top")
    place(state.blocks.lamp)
end

-- bottom piece of right support
dig("down")
down()
place(state.blocks.support, "top")
left()
dig()
forward()
up()

-- place remaining chests
right()
forward(3)
right()

for _ = 1, state.layers do
    up()
    place(state.blocks.chest)
    up()
end

left()
forward(2)
right()

for i = 1, state.layers + 1 do
    place(state.blocks.chest)

    if i ~= 5 then
        down(2)
    end
end

-- move to backside
left()
forward()
down()
right()
forward()
dig()
forward()
up()
left()
back(2)

local function placeBacksideBlocks()
    place(state.blocks.filler, "down")
    right()
    forward()
    place(state.blocks.filler, "down")
    back()
    left()

    for _ = 1, 3 do
        forward()
        place(state.blocks.backside, "down")
    end

    back()
end

-- place outer redstone circuit from chest to lamps
---@param isBottomLayer boolean
local function placeOuterRedstone(isBottomLayer)
    local function placeBottomLayerBlock()
        down()
        dig("down")
        place(state.blocks.filler, "down")
        up()
    end

    right()
    forward()
    dig("down")
    place(state.blocks.filler, "down")
    up()
    place(state.blocks.comparator, "down")
    forward()
    place(state.blocks.filler, "down")
    right()
    forward()

    if isBottomLayer then
        placeBottomLayerBlock()
    end

    place(state.blocks.repeater, "down")
    forward()
    place(state.blocks.filler, "down")
    forward()

    if isBottomLayer then
        placeBottomLayerBlock()
    end

    place(state.blocks.repeater, "down")
    forward()
    place(state.blocks.filler, "down")
    right()

    for _ = 1, 2 do
        forward()
        down()

        if isBottomLayer then
            dig("down")
        end

        place(state.blocks.filler, "down")
        up()
        place(state.blocks.redstone, "down")
    end

    right()
    forward(2)
    placeBacksideBlocks()
end

-- place inner redstone circuit from chest to lamps
local function placeInnerRedstone()
    back()
    right()
    forward()
    place(state.blocks.filler, "down")
    up()
    place(state.blocks.comparator, "down")
    forward()
    place(state.blocks.filler, "down")
    right()
    forward()
    place(state.blocks.repeater, "down")
    forward()
    place(state.blocks.filler, "down")
    right()
    forward()
    down()
    place(state.blocks.filler, "down")
    up()
    place(state.blocks.repeater, "down")
    forward()
    down()
    place(state.blocks.filler, "down")
    up()
    place(state.blocks.filler, "down")
    right()
    forward()
    placeBacksideBlocks()
end

for i = 1, (state.layers * 2) + 1 do
    if i % 2 == 1 then
        placeOuterRedstone(i == 1)
    else
        placeInnerRedstone()
    end
end

-- build input chest
forward()
left()
back()
down()
dig()
place(state.blocks.hopper)
right()
forward(2)
left()
forward()
left()
place(state.blocks.hopper)

-- redstone torch
down()
forward()
left()
place(state.blocks.filler)
down()
place(state.blocks.redstoneTorch, "up")

-- "plus" construct
forward(2)
up()
place(state.blocks.filler, "down")
around()
up()
place(state.blocks.repeater, "down")
back()
place(state.blocks.filler, "down")
up()
place(state.blocks.redstone, "down")

for _ = 1, 2 do
    forward()
    place(state.blocks.filler, "down")
end

around()
up()

-- input chest connection to topmost redstone lamp
place(state.blocks.comparator, "down")
forward()
place(state.blocks.redstone, "down")
right()
forward()
down()
place(state.blocks.filler, "down")
up()
place(state.blocks.redstone, "down")
forward()
place(state.blocks.repeater, "down")
forward()
place(state.blocks.filler, "down")
forward()
place(state.blocks.repeater, "down")
forward()
place(state.blocks.filler, "down")
right()
forward()
down()
place(state.blocks.filler, "down")
up()
place(state.blocks.repeater, "down")
forward()
down()
place(state.blocks.filler, "down")
up()
place(state.blocks.filler, "down")

-- last row of chest backing blocks + input chest
right()
forward()
placeBacksideBlocks()
forward(2)
left()
place(state.blocks.chest, "down")

-- go back home while placing last column of filler blocks
back()
left()
forward()
down()

for _ = 1, (state.layers * 2) + 1 do
    down()
    place(state.blocks.filler, "top")
end

back()
place(state.blocks.filler)
right()
forward()
down()
forward(2)
up()
------------------------------
-- done!
if state.lampLocation == "right" then
    around()
else
    squirtleTurn("right")
    move("forward", 6)
    squirtleTurn("right")
end
