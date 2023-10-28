local Squirtle = require "squirtle"

local move = Squirtle.move
local turn = Squirtle.turn
local put = Squirtle.put

local restoreBreakable = Squirtle.setBreakable(function()
    return true
end)

---@param state BoneMealAppState
local function placeCollectorChest(state)
    -- place collector chest
    move("forward", 2)
    turn("right")
    move("forward", 4)
    turn("left")
    move("forward")
    put("front", state.blocks.filler)
    move("back")
    put("front", state.blocks.chest)
    turn("right")
    move("forward")
    turn("left")
    move("forward")
    put("front", state.blocks.filler)
    move("back")
    put("front", state.blocks.chest)
end

---@param state BoneMealAppState
local function placeDroppersAndDispenser(state)
    -- place droppers + dispenser
    move("up")
    move("forward", 2)
    turn("right")
    move("up")
    put("bottom", state.blocks.dropper)
    move("up")
    put("bottom", state.blocks.dropper)
    move("up")
    put("bottom", state.blocks.dispenser)
end

---@param state BoneMealAppState
local function placeObserver(state)
    -- place observer
    move("forward")
    turn("right")
    move("forward")
    put("bottom", state.blocks.observer)

    -- place observer redstone
    move("back")
    move("down")
    move("down")
    put("bottom", state.blocks.filler)
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)
    turn("left")
    move("forward")
    turn("right")
    move("forward")
    turn("left")
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.stickyPiston)
end

---@param state BoneMealAppState
local function placeChestHopperAndDropperRedstone(state)
    -- place chest hopper & dropper redstone
    turn("left")
    move("forward", 2)
    move("down", 2)
    turn("left")
    move("forward", 3)

    move("down")
    turn("left")
    put("front", state.blocks.hopper)
    turn("right")
    move("up")

    put("bottom", state.blocks.filler)
    turn("right")
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.comparator)
    turn("left")
    move("forward")
    move("down")
    put("bottom", state.blocks.filler)
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)
    move("back")
    put("bottom", state.blocks.redstone)
    move("back")
    move("down")
    put("bottom", state.blocks.redstoneTorch)
end

---@param state BoneMealAppState
local function placeCompostersAndHoppers(state)
    -- place composter hoppers
    move("back", 2)
    turn("right")
    move("forward")
    turn("left")
    put("front", state.blocks.hopper)
    turn("left")
    move("forward", 2)
    turn("right")
    move("forward")
    turn("right")

    for i = 1, 4 do
        put("front", state.blocks.hopper)

        if i ~= 4 then
            move("back")
        end
    end

    turn("left")
    move("forward", 2)
    turn("right")
    move("forward")
    turn("right")
    put("front", state.blocks.hopper)

    -- place composters
    move("up", 2)

    for _ = 1, 2 do
        move("forward")
        put("bottom", state.blocks.composter)
    end

    turn("left")

    for _ = 1, 4 do
        move("forward")
        put("bottom", state.blocks.composter)
    end
end

---@param state BoneMealAppState
local function placeFurnacesAndWall(state)
    -- place furnaces + wall
    move("up")
    turn("right")

    for i = 1, 3 do
        move("forward")

        if i ~= 3 then
            put("bottom", state.blocks.filler)
        end
    end

    turn("right")
    move("up")
    move("forward")

    for i = 1, 3 do
        put("bottom", state.blocks.furnace)
        move("forward")
    end

    put("bottom", state.blocks.filler)
    move("forward")
    put("bottom", state.blocks.filler)
    move("up")
    turn("back")

    for i = 1, 5 do
        put("bottom", state.blocks.filler)
        move("forward")
    end

    move("down")
    move("forward")

    for i = 1, 3 do
        put("bottom", state.blocks.furnace)
        move("forward")
    end

    put("bottom", state.blocks.filler)
    move("up")
    turn("back")

    for i = 1, 4 do
        put("bottom", state.blocks.filler)
        move("forward")
    end

    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.filler)
end

---@param state BoneMealAppState
local function placeWaterHopperWall(state)
    -- build water hopper wall
    move("forward", 5)
    turn("right")

    for i = 1, 8 do
        move("forward")
        put("bottom", state.blocks.filler)
    end

    move("forward")
    move("down", 3)
    turn("back")

    for i = 1, 8 do
        move("forward")

        if (i > 1 and i < 5) or i == 7 then
            turn("left")
            put("front", state.blocks.filler)
            turn("right")
        elseif i == 5 or i == 6 then
            turn("left")
            put("front", state.blocks.hopper)
            turn("right")
        end

        put("top", state.blocks.filler)
    end
end

---@param state BoneMealAppState
local function placeFloorLineTowardsWaterReservoir(state)
    -- build floor line towards water reservoir
    turn("left")
    move("down")

    for i = 1, 8 do
        move("forward")
        put("top", state.blocks.filler)
    end
end

---@param state BoneMealAppState
local function placeRedstonePathToFloodGates(state)
    -- place redstone path to flood gates
    move("down")
    turn("left")
    move("forward", 1)
    put("front", state.blocks.redstoneBlock)
    turn("right")
    move("forward")
    turn("left")
    move("forward")
    turn("right")

    ---@param block string
    local function placeFloored(block)
        move("down")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", block)
    end

    placeFloored(state.blocks.redstone)
    move("forward")
    placeFloored(state.blocks.comparator)
    move("forward")
    placeFloored(state.blocks.redstone)
    turn("left")
    move("forward")
    placeFloored(state.blocks.redstone)
    turn("left")
    move("forward")
    placeFloored(state.blocks.comparator)
    move("forward")
    placeFloored(state.blocks.redstone)

    move("back", 3)
    move("down")
    turn("right")

    for i = 1, 4 do
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.redstone)

        if i ~= 4 then
            move("forward")
        end
    end

    turn("left")
    move("forward")
    move("down")
    put("bottom", state.blocks.filler)
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.repeater)
    put("front", state.blocks.redstoneTorch)
end

---@param state BoneMealAppState
local function placeReservoirWallsAndFloor(state)
    -- place reservoir walls and floor
    move("up")
    move("forward", 2)
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)
    put("bottom", state.blocks.filler)

    for i = 1, 6 do
        move("back")
        put("bottom", state.blocks.filler)
    end

    move("up")
    move("back")
    turn("right")
    move("forward")
    turn("left")
    put("bottom", state.blocks.filler)
    move("forward")

    for i = 1, 7 do
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", state.blocks.redstone)

        if i ~= 7 then
            move("forward")
            move("down")
        end
    end
end

---@param state BoneMealAppState
local function placeTrapdoors(state)
    turn("left")
    move("forward")
    move("down")
    put("bottom", state.blocks.trapdoor)

    for _ = 1, 6 do
        turn("left")
        move("forward")
        turn("right")
        put("bottom", state.blocks.trapdoor)
    end
end

---@param state BoneMealAppState
local function placeRemainingFloor(state)
    move("forward")
    move("down", 2)
    turn("right")
    move("forward")
    turn("left")

    for i = 1, 7 do
        if i ~= 4 then
            put("bottom", state.blocks.filler)
        end

        if i ~= 7 then
            move("forward")
        end
    end

    -- place containing observer
    turn("right")
    move("forward")
    turn("right")

    for i = 1, 6 do
        put("bottom", state.blocks.filler)

        if i == 4 then
            move("up")
            move("forward", 2)
            move("down")
        elseif i ~= 6 then
            move("forward")
        end
    end

    -- place line containing dispenser
    turn("left")
    move("forward")
    turn("left")

    for i = 1, 7 do
        if i ~= 4 then
            put("bottom", state.blocks.filler)
        end

        if i ~= 7 then
            move("forward")
        end
    end

    -- place remaining 4 lines
    for line = 1, 4 do
        if line % 2 == 1 then
            turn("right")
            move("forward")
            turn("right")
        else
            turn("left")
            move("forward")
            turn("left")
        end

        for i = 1, 7 do
            put("bottom", state.blocks.filler)

            if i ~= 7 then
                move("forward")
            end
        end
    end
end

---@param state BoneMealAppState
local function placePistonsAndWalls(state)
    move("forward")
    move("up")
    turn("left")
    put("bottom", state.blocks.filler)
    move("back")
    put("bottom", state.blocks.filler)
    put("front", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)
    put("bottom", state.blocks.filler)
    move("back")
    put("bottom", state.blocks.filler)

    -- place pistons
    turn("left")
    move("forward")
    move("down")

    for i = 1, 7 do
        turn("right")

        if i == 4 then
            move("forward", 2)
            put("front", state.blocks.filler)
            move("back", 2)
            put("front", state.blocks.filler)
        else
            put("front", state.blocks.piston)
        end

        turn("left")
        move("forward")
    end

    -- place remaining wall
    turn("right")
    move("forward")
    put("front", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)

    -- place lever
    turn("right")
    move("back")
    move("up")
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstoneTorch)
    move("forward")
    move("up")
    put("bottom", state.blocks.lever)

    -- place piston redstone
    move("forward")
    move("down")

    ---@param block string
    local function placeFloored(block)
        move("down")
        put("bottom", state.blocks.filler)
        move("up")
        put("bottom", block)
    end

    -- dust line directly connected to pistons
    for i = 1, 8 do
        placeFloored(state.blocks.redstone)

        if i ~= 8 then
            move("forward")
        end
    end

    -- first line of repeaters
    turn("right")
    move("forward")
    turn("right")

    for _ = 1, 6 do
        placeFloored(state.blocks.repeater)
        move("forward")
    end

    placeFloored(state.blocks.redstone)
    move("forward")
    move("down")

    for i = 1, 3 do
        put("bottom", state.blocks.filler)

        if i ~= 3 then
            move("forward")
        end
    end

    -- repeater redstone dust connection
    move("up")
    put("bottom", state.blocks.redstone)
    turn("left")
    move("forward")
    placeFloored(state.blocks.redstone)
    turn("left")
    move("forward")

    for _ = 1, 9 do
        placeFloored(state.blocks.repeater)
        move("forward")
    end

    placeFloored(state.blocks.redstone)
    turn("left")
    move("forward")
    placeFloored(state.blocks.redstone)

    -- place last floor line (that i forgot to add in previously)
    move("forward", 3)
    move("down", 4)
    turn("left")
    move("forward", 2)

    for i = 1, 7 do
        put("top", state.blocks.filler)
        move("forward")
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
