local Side = require "lib.apis.side"
local TurtleApi = require "lib.apis.turtle.turtle-api"

local move = TurtleApi.move
local turn = TurtleApi.turn
local put = TurtleApi.put

local strafe = function(direction)
    TurtleApi.turn(direction)
    TurtleApi.move("forward")
    TurtleApi.turn(Side.rotate180(direction))
end

-- [todo] make dedicated methods in TurtleApi for place/take water/lava which also records it as a used item,
-- adding used quantity when placing, removing when taking
---@param state BoneMealAppState
local placeWater = function(state)
    TurtleApi.selectItem(state.blocks.waterBucket)
    TurtleApi.place("down")
end

---@param state BoneMealAppState
local takeWater = function(state)
    TurtleApi.selectItem(state.blocks.bucket)
    return TurtleApi.place("down")
end

---@param state BoneMealAppState
local placeLava = function(state)
    TurtleApi.selectItem(state.blocks.lavaBucket)
    TurtleApi.place("down")
end

---@param state BoneMealAppState
---@param length integer
---@param block? string
local function putLine(state, length, block)
    for i = 1, length do
        put("bottom", block or state.blocks.filler)

        if i ~= length then
            move("forward")
        end
    end
end

---@param direction string
local function moveToNextLine(direction)
    turn(direction)
    move("forward")
    turn(direction)
end

---@param state BoneMealAppState
---@param block string
local function putFloored(state, block)
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", block)
end

local restoreBreakable = TurtleApi.setBreakable(function()
    return true
end)

---@param state BoneMealAppState
local function placeCollectorChest(state)
    move("bottom", 6)
    print("[place] collector chest")
    -- place collector chest
    move("forward", 2)
    turn("right")
    move("forward", 4)
    turn("left")

    local function placeOneChest()
        move("forward")
        put("front", state.blocks.filler)
        move("back")
        put("front", state.blocks.chest)
    end

    placeOneChest()
    strafe("right")
    placeOneChest()
end

---@param state BoneMealAppState
local function placeDroppersAndDispenser(state)
    print("[place] dropper + dispenser")
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
    print("[place] observer")
    -- place observer
    move("forward")
    turn("right")
    move("forward")
    put("bottom", state.blocks.observer)

    -- place observer redstone
    move("back")
    move("down", 2)
    put("bottom", state.blocks.filler)
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)
    strafe("left")
    move("forward")
    turn("left")
    move("down")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.stickyPiston)
    move("forward")
    move("down", 2)
    turn("back")
    put("front", state.blocks.redstoneBlock)

end

---@param state BoneMealAppState
local function placeRedstonePathToFloodGates(state)
    -- place redstone path to flood gates
    turn("left")
    move("down")

    for i = 1, 3 do
        put("bottom", state.blocks.filler)

        if i ~= 3 then
            move("back")
        end
    end

    move("up")
    put("bottom", state.blocks.redstone)
    move("forward")
    put("bottom", state.blocks.comparator)
    move("forward")
    put("bottom", state.blocks.redstone)
    moveToNextLine("left")
    move("down")
    putLine(state, 4)
    move("up")
    put("bottom", state.blocks.redstone)
    move("back")
    put("bottom", state.blocks.redstone)
    move("back")
    put("bottom", state.blocks.comparator)
    move("back")
    put("bottom", state.blocks.redstone)

    move("forward", 2)
    put("top", state.blocks.filler)
    move("forward")
    put("top", state.blocks.filler)
    turn("left")
    move("forward")
    put("bottom", state.blocks.filler)
    turn("left")
    put("front", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)

    move("forward")
    move("up")
    put("bottom", state.blocks.redstone)
    moveToNextLine("left")
    move("up")
    put("bottom", state.blocks.redstone)
    move("forward")
    put("bottom", state.blocks.redstone)
    move("forward")
    put("bottom", state.blocks.filler)
    turn("left")
    move("back")
    put("front", state.blocks.redstoneTorch)
end

---@param state BoneMealAppState
local function placeWaterReservoir(state)
    print("[place] water reservoir")
    -- place water reservoir
    move("up")
    move("forward", 2)
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)
    put("bottom", state.blocks.filler)

    for _ = 1, 6 do
        move("back")
        put("bottom", state.blocks.filler)
    end

    move("up")
    move("back")
    put("bottom", state.blocks.filler)
    strafe("right")

    for i = 1, 8 do
        put("bottom", state.blocks.filler)

        if i ~= 8 then
            move("forward")
        end
    end

    -- place trapdoor redstone dust line
    move("up")

    for i = 1, 7 do
        put("bottom", state.blocks.redstone)

        if i ~= 7 then
            move("back")
        end
    end

    -- place trapdoors
    turn("left")
    move("forward")
    move("down")
    put("bottom", state.blocks.trapdoor)

    for _ = 1, 6 do
        strafe("right")
        put("bottom", state.blocks.trapdoor)
    end

    -- place water

    turn("left")
    placeWater(state)
    move("forward", 2)
    placeWater(state)

    for _ = 1, 2 do
        move("back")
        takeWater(state)
        move("forward", 3)
        placeWater(state)
    end

    -- collect 2x water buckets for item collection water
    move("back")
    takeWater(state)

    while not takeWater(state) do
        os.sleep(.5)
    end

    move("forward")
end

---@param state BoneMealAppState
local function placeFurnaceWall(state)
    print("[place] furnaces + back wall")
    move("forward")
    turn("left")
    move("back")
    move("down")

    for i = 1, 7 do
        if i == 4 then
            put("bottom", state.blocks.filler)
        else
            put("bottom", state.blocks.furnace)
        end

        move("back")
        put("front", state.blocks.filler)
    end
end

---@param state BoneMealAppState
local function placeWaterItemCollection(state)
    print("[place] water item collection")
    put("bottom", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)
    turn("right")
    move("back")
    put("front", state.blocks.filler)

    for _ = 1, 8 do
        put("bottom", state.blocks.filler)
        move("back")
        put("front", state.blocks.filler)
    end

    turn("left")
    move("forward")
    turn("left")
    move("back")
    put("bottom", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)
    move("down")

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", true)
    end

    for i = 1, 7 do
        if i == 4 or i == 5 then
            put("bottom", state.blocks.hopper)
        else
            put("bottom", state.blocks.filler)
        end

        if i ~= 7 then
            move("back")
        end
    end

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", false)
    end

    turn("left")
    move("back")
    turn("left")

    for _ = 1, 8 do
        put("bottom", state.blocks.filler)
        move("back")
        put("front", state.blocks.stone)
    end

    put("bottom", state.blocks.filler)
    turn("right")
    put("front", state.blocks.filler)
    move("up")
    put("front", state.blocks.filler)
    turn("left")
    move("forward", 2)
    strafe("right")
    placeWater(state)
    move("forward", 2)
    placeWater(state)
    takeWater(state)
    move("back")
    takeWater(state)
    move("forward", 5)
    placeWater(state)
end

---@param state BoneMealAppState
local function placeFloor(state)
    turn("left")
    move("forward", 2)
    move("down")

    putLine(state, 6)

    moveToNextLine("left")
    putLine(state, 6)

    moveToNextLine("right")
    putLine(state, 3)
    -- avoid observer
    move("up")
    move("forward", 2)
    move("down")
    putLine(state, 2)

    moveToNextLine("left")
    putLine(state, 3)
    move("forward")
    TurtleApi.selectItem(state.blocks.boneMeal)
    TurtleApi.drop("down")
    move("forward")
    putLine(state, 2)

    for _ = 1, 2 do
        moveToNextLine("right")
        putLine(state, 6)
        moveToNextLine("left")
        putLine(state, 6)
    end

    moveToNextLine("right")
    putLine(state, 6)
end

---@param state BoneMealAppState
local function buildPistonSystem(state)
    move("forward")
    turn("right")
    move("back")
    put("front", state.blocks.filler)
    move("back")
    put("front", state.blocks.filler)

    for i = 1, 8 do
        strafe("right")
        if i == 4 then
            move("forward", 2)
            put("front", state.blocks.filler)
            move("back", 2)
            put("front", state.blocks.filler)
        elseif i == 8 then
            put("front", state.blocks.filler)
        else
            put("front", state.blocks.piston)
        end
    end

    move("up")
    turn("left")
    move("forward")
    putLine(state, 7)
    moveToNextLine("left")
    putLine(state, 9)
    moveToNextLine("right")
    putLine(state, 11)
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    move("up")
    put("bottom", state.blocks.redstone)
    move("back")
    put("bottom", state.blocks.redstone)
    turn("right")
    move("forward")
    putLine(state, 9, state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.redstone)
    moveToNextLine("left")
    put("bottom", state.blocks.redstone)
    move("forward")
    putLine(state, 6, state.blocks.repeater)
    move("forward")
    put("bottom", state.blocks.redstone)
    move("forward")
    put("bottom", state.blocks.redstoneBlock)

    move("forward")
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    turn("right")
    move("back")
    put("bottom", state.blocks.redstoneTorch)
    move("forward")
    move("forward")
    putLine(state, 7, state.blocks.redstone)
end

---@param state BoneMealAppState
local function buildPistonFluidsWall(state)
    move("forward")
    moveToNextLine("left")
    putLine(state, 9)
    turn("right")
    move("forward")
    put("bottom", state.blocks.filler)
    move("forward")
    turn("right")
    move("forward")
    putLine(state, 7)
    move("up")
    turn("back")
    putLine(state, 8)
    turn("left")
    move("forward")
    put("bottom", state.blocks.filler)
    move("forward")
    turn("left")
    putLine(state, 9)
    turn("left")
    move("forward")
    putLine(state, 2)

    -- place water + lava
    move("back")
    turn("left")
    move("forward", 4)
    move("down", 2)
    placeWater(state)
    move("up")
    put("bottom", state.blocks.filler)
    move("up")
    placeLava(state)
end

---@param state BoneMealAppState
local function buildStoneFloor(state)
    move("forward", 3)
    turn("right")
    move("forward", 2)
    move("down", 2)
    turn("right")
    putLine(state, 6, state.blocks.stone)
    moveToNextLine("left")
    putLine(state, 6, state.blocks.stone)
    moveToNextLine("right")
    putLine(state, 6, state.blocks.stone)
    moveToNextLine("left")
    putLine(state, 2, state.blocks.stone)
    move("forward")
    put("bottom", state.blocks.moss)
    move("forward")
    putLine(state, 3, state.blocks.stone)
    moveToNextLine("right")
    putLine(state, 2, state.blocks.stone)
    move("forward", 2)
    putLine(state, 3, state.blocks.stone)
    moveToNextLine("left")
    putLine(state, 6, state.blocks.stone)
    moveToNextLine("right")
    putLine(state, 6, state.blocks.stone)
end

---@param state BoneMealAppState
local function buildCompostersAndHoppers(state)
    print("[place] composter + hoppers")
    move("up")
    turn("left")
    move("forward", 2)
    move("down", 5)
    move("back", 3)
    turn("left")
    move("forward", 2)
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
    moveToNextLine("right")
    put("front", state.blocks.hopper)
    move("up")
    turn("back")

    -- making sure we do not load from shulker during hopper placement,
    -- as the hoppers will suck items from the shulker
    TurtleApi.selectItem(state.blocks.composter)

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", true)
    end

    move("back", 2)
    put("front", state.blocks.composter)
    turn("left")

    for _ = 1, 3 do
        move("back")
        put("front", state.blocks.composter)
    end

    turn("back")
    put("front", state.blocks.composter)
    turn("right")
    move("back")
    put("front", state.blocks.composter)

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", false)
    end
end

---@param state BoneMealAppState
local function buildDropperRedstone(state)
    move("back")
    move("down", 2)
    strafe("left")
    put("front", state.blocks.hopper)
    move("up")
    put("bottom", state.blocks.filler)
    move("up")
    turn("back")
    put("bottom", state.blocks.comparator)
    move("forward")
    put("bottom", state.blocks.filler)
    turn("left")
    move("forward")
    move("down")
    turn("left")
    putLine(state, 2)
    move("forward")
    put("bottom", state.blocks.redstoneTorch)
    move("up")

    for _ = 1, 2 do
        move("back")
        put("bottom", state.blocks.redstone)
    end
end

---@param state BoneMealAppState
return function(state)
    placeCollectorChest(state)
    placeDroppersAndDispenser(state)
    placeObserver(state)
    placeRedstonePathToFloodGates(state)
    placeWaterReservoir(state)
    placeFurnaceWall(state)
    placeWaterItemCollection(state)
    placeFloor(state)
    buildPistonSystem(state)
    buildPistonFluidsWall(state)
    buildStoneFloor(state)
    buildCompostersAndHoppers(state)
    buildDropperRedstone(state)
    restoreBreakable()
end
