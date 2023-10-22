local SquirtleV2 = require "squirtle.squirtle-v2"

local move = SquirtleV2.move
local forward = SquirtleV2.forward
local up = SquirtleV2.up
local down = SquirtleV2.down
local back = SquirtleV2.back
local right = SquirtleV2.right
local left = SquirtleV2.left
local place = SquirtleV2.place
local placeUp = SquirtleV2.placeUp
local placeDown = SquirtleV2.placeDown
local around = SquirtleV2.around

local restoreBreakable = SquirtleV2.setBreakable(function()
    return true
end)

---@param state BoneMealAppState
local function placeCollectorChest(state)
    -- place collector chest
    forward(2)
    right()
    forward(4)
    left()
    forward()
    place(state.blocks.filler)
    back()
    place(state.blocks.chest)
    right()
    forward()
    left()
    forward()
    place(state.blocks.filler)
    back()
    place(state.blocks.chest)
end

---@param state BoneMealAppState
local function placeDroppersAndDispenser(state)
    -- place droppers + dispenser
    up()
    forward(2)
    right()
    up()
    placeDown(state.blocks.dropper)
    up()
    placeDown(state.blocks.dropper)
    up()
    placeDown(state.blocks.dispenser)
end

---@param state BoneMealAppState
local function placeObserver(state)
    -- place observer
    forward()
    right()
    forward()
    placeDown(state.blocks.observer)

    -- place observer redstone
    back()
    down()
    down()
    placeDown(state.blocks.filler)
    place(state.blocks.filler)
    up()
    placeDown(state.blocks.redstone)
    left()
    forward()
    right()
    forward()
    left()
    down()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.repeater)
    forward()
    placeDown(state.blocks.stickyPiston)
end

---@param state BoneMealAppState
local function placeChestHopperAndDropperRedstone(state)
    -- place chest hopper & dropper redstone
    left()
    forward(2)
    down(2)
    left()
    forward(3)

    down()
    left()
    place(state.blocks.hopper)
    right()
    up()

    placeDown(state.blocks.filler)
    right()
    place(state.blocks.filler)
    up()
    placeDown(state.blocks.comparator)
    left()
    forward()
    down()
    placeDown(state.blocks.filler)
    right()
    forward()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.redstone)
    back()
    placeDown(state.blocks.redstone)
    back()
    down()
    placeDown(state.blocks.redstoneTorch)
end

---@param state BoneMealAppState
local function placeCompostersAndHoppers(state)
    -- place composter hoppers
    back(2)
    right()
    forward()
    left()
    place(state.blocks.hopper)
    left()
    forward(2)
    right()
    forward()
    right()

    for i = 1, 4 do
        place(state.blocks.hopper)

        if i ~= 4 then
            back()
        end
    end

    left()
    forward(2)
    right()
    forward()
    right()
    place(state.blocks.hopper)

    -- place composters
    up(2)

    for _ = 1, 2 do
        forward()
        placeDown(state.blocks.composter)
    end

    left()

    for _ = 1, 4 do
        forward()
        placeDown(state.blocks.composter)
    end
end

---@param state BoneMealAppState
local function placeFurnacesAndWall(state)
    -- place furnaces + wall
    up()
    right()

    for i = 1, 3 do
        forward()

        if i ~= 3 then
            placeDown(state.blocks.filler)
        end
    end

    right()
    up()
    forward()

    for i = 1, 3 do
        placeDown(state.blocks.furnace)
        forward()
    end

    placeDown(state.blocks.filler)
    forward()
    placeDown(state.blocks.filler)
    up()
    around()

    for i = 1, 5 do
        placeDown(state.blocks.filler)
        forward()
    end

    down()
    forward()

    for i = 1, 3 do
        placeDown(state.blocks.furnace)
        forward()
    end

    placeDown(state.blocks.filler)
    up()
    around()

    for i = 1, 4 do
        placeDown(state.blocks.filler)
        forward()
    end

    down()
    placeDown(state.blocks.filler)
    up()
    placeDown(state.blocks.filler)
end

---@param state BoneMealAppState
local function placeWaterHopperWall(state)
    -- build water hopper wall
    forward(5)
    right()

    for i = 1, 8 do
        forward()
        placeDown(state.blocks.filler)
    end

    forward()
    down(3)
    around()

    for i = 1, 8 do
        forward()

        if (i > 1 and i < 5) or i == 7 then
            left()
            place(state.blocks.filler)
            right()
        elseif i == 5 or i == 6 then
            left()
            place(state.blocks.hopper)
            right()
        end

        placeUp(state.blocks.filler)
    end
end

---@param state BoneMealAppState
local function placeFloorLineTowardsWaterReservoir(state)
    -- build floor line towards water reservoir
    left()
    down()

    for i = 1, 8 do
        forward()
        placeUp(state.blocks.filler)
    end
end

---@param state BoneMealAppState
local function placeRedstonePathToFloodGates(state)
    -- place redstone path to flood gates
    down()
    left()
    forward(1)
    place(state.blocks.redstoneBlock)
    right()
    forward()
    left()
    forward()
    right()

    ---@param block string
    local function placeFloored(block)
        down()
        placeDown(state.blocks.filler)
        up()
        placeDown(block)
    end

    placeFloored(state.blocks.redstone)
    forward()
    placeFloored(state.blocks.comparator)
    forward()
    placeFloored(state.blocks.redstone)
    left()
    forward()
    placeFloored(state.blocks.redstone)
    left()
    forward()
    placeFloored(state.blocks.comparator)
    forward()
    placeFloored(state.blocks.redstone)

    back(3)
    down()
    right()

    for i = 1, 4 do
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.redstone)

        if i ~= 4 then
            forward()
        end
    end

    left()
    forward()
    down()
    placeDown(state.blocks.filler)
    place(state.blocks.filler)
    up()
    placeDown(state.blocks.repeater)
    place(state.blocks.redstoneTorch)
end

---@param state BoneMealAppState
local function placeReservoirWallsAndFloor(state)
    -- place reservoir walls and floor
    up()
    forward(2)
    right()
    forward()
    placeDown(state.blocks.filler)
    back()
    place(state.blocks.filler)
    placeDown(state.blocks.filler)

    for i = 1, 6 do
        back()
        placeDown(state.blocks.filler)
    end

    up()
    back()
    right()
    forward()
    left()
    placeDown(state.blocks.filler)
    forward()

    for i = 1, 7 do
        placeDown(state.blocks.filler)
        up()
        placeDown(state.blocks.redstone)

        if i ~= 7 then
            forward()
            down()
        end
    end
end

---@param state BoneMealAppState
local function placeTrapdoors(state)
    left()
    forward()
    down()
    placeDown(state.blocks.trapdoor)

    for _ = 1, 6 do
        left()
        forward()
        right()
        placeDown(state.blocks.trapdoor)
    end
end

---@param state BoneMealAppState
local function placeRemainingFloor(state)
    forward()
    down(2)
    right()
    forward()
    left()

    for i = 1, 7 do
        if i ~= 4 then
            placeDown(state.blocks.filler)
        end

        if i ~= 7 then
            forward()
        end
    end

    -- place containing observer
    right()
    forward()
    right()

    for i = 1, 6 do
        placeDown(state.blocks.filler)

        if i == 4 then
            up()
            forward(2)
            down()
        elseif i ~= 6 then
            forward()
        end
    end

    -- place line containing dispenser
    left()
    forward()
    left()

    for i = 1, 7 do
        if i ~= 4 then
            placeDown(state.blocks.filler)
        end

        if i ~= 7 then
            forward()
        end
    end

    -- place remaining 4 lines
    for line = 1, 4 do
        if line % 2 == 1 then
            right()
            forward()
            right()
        else
            left()
            forward()
            left()
        end

        for i = 1, 7 do
            placeDown(state.blocks.filler)

            if i ~= 7 then
                forward()
            end
        end
    end
end

---@param state BoneMealAppState
local function placePistonsAndWalls(state)
    forward()
    up()
    left()
    placeDown(state.blocks.filler)
    back()
    placeDown(state.blocks.filler)
    place(state.blocks.filler)
    back()
    place(state.blocks.filler)
    placeDown(state.blocks.filler)
    back()
    placeDown(state.blocks.filler)

    -- place pistons
    left()
    forward()
    down()

    for i = 1, 7 do
        right()

        if i == 4 then
            forward(2)
            place(state.blocks.filler)
            back(2)
            place(state.blocks.filler)
        else
            place(state.blocks.piston)
        end

        left()
        forward()
    end

    -- place remaining wall
    right()
    forward()
    place(state.blocks.filler)
    back()
    place(state.blocks.filler)

    -- place lever
    right()
    back()
    up()
    place(state.blocks.filler)
    up()
    placeDown(state.blocks.redstoneTorch)
    forward()
    up()
    placeDown(state.blocks.lever)

    -- place piston redstone
    forward()
    down()

    ---@param block string
    local function placeFloored(block)
        down()
        placeDown(state.blocks.filler)
        up()
        placeDown(block)
    end

    -- dust line directly connected to pistons
    for i = 1, 8 do
        placeFloored(state.blocks.redstone)

        if i ~= 8 then
            forward()
        end
    end

    -- first line of repeaters
    right()
    forward()
    right()

    for _ = 1, 6 do
        placeFloored(state.blocks.repeater)
        forward()
    end

    placeFloored(state.blocks.redstone)
    forward()
    down()

    for i = 1, 3 do
        placeDown(state.blocks.filler)

        if i ~= 3 then
            forward()
        end
    end

    -- repeater redstone dust connection
    up()
    placeDown(state.blocks.redstone)
    left()
    forward()
    placeFloored(state.blocks.redstone)
    left()
    forward()

    for _ = 1, 9 do
        placeFloored(state.blocks.repeater)
        forward()
    end

    placeFloored(state.blocks.redstone)
    left()
    forward()
    placeFloored(state.blocks.redstone)

    -- place last floor line (that i forgot to add in previously)
    forward(3)
    down(4)
    left()
    forward(2)

    for i = 1, 7 do
        placeUp(state.blocks.filler)
        forward()
    end
end

---@param state BoneMealAppState
return function(state)
    placeCollectorChest(state)
    placeDroppersAndDispenser(state)
    placeObserver(state)
    placeChestHopperAndDropperRedstone(state)
    placeCompostersAndHoppers(state)
    placeFurnacesAndWall(state)
    placeWaterHopperWall(state)
    placeFloorLineTowardsWaterReservoir(state)
    placeRedstonePathToFloodGates(state)
    placeReservoirWallsAndFloor(state)
    placeTrapdoors(state)
    placeRemainingFloor(state)
    placePistonsAndWalls(state)

    restoreBreakable()
end
