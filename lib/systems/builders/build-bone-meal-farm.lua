local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"

local move = TurtleApi.move
local turn = TurtleApi.turn
local put = TurtleApi.put
local strafe = TurtleApi.strafe

-- [todo] ❌ make dedicated methods in TurtleApi for place/take water/lava which also records it as a used item, adding used quantity when placing, removing when taking
-- [todo] ❌ make placing/taking water/lava resumable
local placeWater = function()
    TurtleApi.selectItem(ItemApi.waterBucket)
    TurtleApi.place("down")
end

local takeWater = function()
    TurtleApi.selectItem(ItemApi.bucket)
    return TurtleApi.place("down")
end

local placeLava = function()
    TurtleApi.selectItem(ItemApi.lavaBucket)
    TurtleApi.place("down")
end

---@param length integer
---@param block? string
local function putLine(length, block)
    for i = 1, length do
        put("bottom", block or ItemApi.smoothStone)

        if i ~= length then
            move("forward")
        end
    end
end

---@param direction string
local function uturn(direction)
    turn(direction)
    move("forward")
    turn(direction)
end

local function placeCollectorChest()
    move("down", 6)

    if not TurtleApi.isSimulating() then
        print("[place] collector chest")
    end

    -- place collector chest
    move("forward", 2)
    turn("right")
    move("forward", 4)
    turn("left")

    local function placeOneChest()
        move("forward")
        put("front", ItemApi.smoothStone)
        move("back")
        put("front", ItemApi.chest)
    end

    placeOneChest()
    strafe("right")
    placeOneChest()
end

local function placeDroppersAndDispenser()
    if not TurtleApi.isSimulating() then
        print("[place] dropper + dispenser")
    end

    -- place droppers + dispenser
    move("up")
    move("forward", 2)
    turn("right")
    move("up")
    put("bottom", ItemApi.dropper)
    move("up")
    put("bottom", ItemApi.dropper)
    move("up")
    put("bottom", ItemApi.dispenser)
end

local function placeObserver()
    if not TurtleApi.isSimulating() then
        print("[place] observer")
    end

    -- place observer
    move("forward")
    turn("right")
    move("forward")
    put("bottom", ItemApi.observer)

    -- place observer redstone
    move("back")
    move("down", 2)
    put("bottom", ItemApi.smoothStone)
    put("front", ItemApi.smoothStone)
    move("up")
    put("bottom", ItemApi.redstone)
    strafe("left")
    move("forward")
    turn("left")
    move("down")
    put("bottom", ItemApi.smoothStone)
    move("up")
    put("bottom", ItemApi.repeater)
    move("forward")
    put("bottom", ItemApi.stickyPiston)
    move("forward")
    move("down", 2)
    turn("back")
    put("front", ItemApi.redstoneBlock)

end

local function placeRedstonePathToFloodGates()
    -- place redstone path to flood gates
    turn("left")
    move("down")

    for i = 1, 3 do
        put("bottom", ItemApi.smoothStone)

        if i ~= 3 then
            move("back")
        end
    end

    move("up")
    put("bottom", ItemApi.redstone)
    move("forward")
    put("bottom", ItemApi.comparator)
    move("forward")
    put("bottom", ItemApi.redstone)
    uturn("left")
    move("down")
    putLine(4)
    move("up")
    put("bottom", ItemApi.redstone)
    move("back")
    put("bottom", ItemApi.redstone)
    move("back")
    put("bottom", ItemApi.comparator)
    move("back")
    put("bottom", ItemApi.redstone)

    move("forward", 2)
    put("top", ItemApi.smoothStone)
    move("forward")
    put("top", ItemApi.smoothStone)
    turn("left")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    turn("left")
    put("front", ItemApi.smoothStone)
    move("up")
    put("bottom", ItemApi.redstone)

    move("forward")
    move("up")
    put("bottom", ItemApi.redstone)
    uturn("left")
    move("up")
    put("bottom", ItemApi.redstone)
    move("forward")
    put("bottom", ItemApi.redstone)
    move("forward")
    put("bottom", ItemApi.smoothStone)
    turn("left")
    move("back")
    put("front", ItemApi.redstoneTorch)
end

local function placeWaterReservoir()
    if not TurtleApi.isSimulating() then
        print("[place] water reservoir")
    end

    -- place water reservoir
    move("up")
    move("forward", 2)
    turn("right")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    move("back")
    put("front", ItemApi.smoothStone)
    put("bottom", ItemApi.smoothStone)

    for _ = 1, 6 do
        move("back")
        put("bottom", ItemApi.smoothStone)
    end

    move("up")
    move("back")
    put("bottom", ItemApi.smoothStone)
    strafe("right")

    for i = 1, 8 do
        put("bottom", ItemApi.smoothStone)

        if i ~= 8 then
            move("forward")
        end
    end

    -- place trapdoor redstone dust line
    move("up")

    for i = 1, 7 do
        put("bottom", ItemApi.redstone)

        if i ~= 7 then
            move("back")
        end
    end

    -- place trapdoors
    turn("left")
    move("forward")
    move("down")
    put("bottom", ItemApi.trapdoor)

    for _ = 1, 6 do
        strafe("right")
        put("bottom", ItemApi.trapdoor)
    end

    -- place water

    turn("left")
    placeWater()
    move("forward", 2)
    placeWater()

    for _ = 1, 2 do
        move("back")
        takeWater()
        move("forward", 3)
        placeWater()
    end

    -- collect 2x water buckets for item collection water
    move("back")
    takeWater()

    while not takeWater() do
        os.sleep(.5)
    end

    move("forward")
end

local function placeFurnaceWall()
    if not TurtleApi.isSimulating() then
        print("[place] furnaces + back wall")
    end

    move("forward")
    turn("left")
    move("back")
    move("down")

    for i = 1, 7 do
        if i == 4 then
            put("bottom", ItemApi.smoothStone)
        else
            put("bottom", ItemApi.furnace)
        end

        move("back")
        put("front", ItemApi.smoothStone)
    end
end

local function placeWaterItemCollection()
    if not TurtleApi.isSimulating() then
        print("[place] water item collection")
    end

    put("bottom", ItemApi.smoothStone)
    move("back")
    put("front", ItemApi.smoothStone)
    turn("right")
    move("back")
    put("front", ItemApi.smoothStone)

    for _ = 1, 8 do
        put("bottom", ItemApi.smoothStone)
        move("back")
        put("front", ItemApi.smoothStone)
    end

    turn("left")
    move("forward")
    turn("left")
    move("back")
    put("bottom", ItemApi.smoothStone)
    move("back")
    put("front", ItemApi.smoothStone)
    move("down")

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", true)
    end

    for i = 1, 7 do
        if i == 4 or i == 5 then
            put("bottom", ItemApi.hopper)
        else
            put("bottom", ItemApi.smoothStone)
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
        put("bottom", ItemApi.smoothStone)
        move("back")
        put("front", ItemApi.stone)
    end

    put("bottom", ItemApi.smoothStone)
    turn("right")
    put("front", ItemApi.smoothStone)
    move("up")
    put("front", ItemApi.smoothStone)
    turn("left")
    move("forward", 2)
    strafe("right")
    placeWater()
    move("forward", 2)
    placeWater()
    takeWater()
    move("back")
    takeWater()
    move("forward", 5)
    placeWater()
end

local function placeFloor()
    turn("left")
    move("forward", 2)
    move("down")

    putLine(6)

    uturn("left")
    putLine(6)

    uturn("right")
    putLine(3)
    -- avoid observer
    move("up")
    move("forward", 2)
    move("down")
    putLine(2)

    uturn("left")
    putLine(3)
    move("forward")
    TurtleApi.selectItem(ItemApi.boneMeal)
    TurtleApi.drop("down")
    move("forward")
    putLine(2)

    for _ = 1, 2 do
        uturn("right")
        putLine(6)
        uturn("left")
        putLine(6)
    end

    uturn("right")
    putLine(6)
end

local function buildPistonSystem()
    move("forward")
    turn("right")
    move("back")
    put("front", ItemApi.smoothStone)
    move("back")
    put("front", ItemApi.smoothStone)

    for i = 1, 8 do
        strafe("right")
        if i == 4 then
            move("forward", 2)
            put("front", ItemApi.smoothStone)
            move("back", 2)
            put("front", ItemApi.smoothStone)
        elseif i == 8 then
            put("front", ItemApi.smoothStone)
        else
            put("front", ItemApi.piston)
        end
    end

    move("up")
    turn("left")
    move("forward")
    putLine(7)
    uturn("left")
    putLine(9)
    uturn("right")
    putLine(11)
    turn("right")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    move("up")
    put("bottom", ItemApi.redstone)
    move("back")
    put("bottom", ItemApi.redstone)
    turn("right")
    move("forward")
    putLine(9, ItemApi.repeater)
    move("forward")
    put("bottom", ItemApi.redstone)
    uturn("left")
    put("bottom", ItemApi.redstone)
    move("forward")
    putLine(6, ItemApi.repeater)
    move("forward")
    put("bottom", ItemApi.redstone)
    move("forward")
    put("bottom", ItemApi.redstoneBlock)

    move("forward")
    turn("right")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    turn("right")
    move("back")
    put("bottom", ItemApi.redstoneTorch)
    move("forward")
    move("forward")
    putLine(7, ItemApi.redstone)
end

local function buildPistonFluidsWall()
    move("forward")
    uturn("left")
    putLine(9)
    turn("right")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    move("forward")
    turn("right")
    move("forward")
    putLine(7)
    move("up")
    turn("back")
    putLine(8)
    turn("left")
    move("forward")
    put("bottom", ItemApi.smoothStone)
    move("forward")
    turn("left")
    putLine(9)
    turn("left")
    move("forward")
    putLine(2)

    -- place water + lava
    move("back")
    turn("left")
    move("forward", 4)
    move("down", 2)
    placeWater()
    move("up")
    put("bottom", ItemApi.smoothStone)
    move("up")
    placeLava()
end

local function buildStoneFloor()
    move("forward", 3)
    turn("right")
    move("forward", 2)
    move("down", 2)
    turn("right")
    putLine(6, ItemApi.stone)
    uturn("left")
    putLine(6, ItemApi.stone)
    uturn("right")
    putLine(6, ItemApi.stone)
    uturn("left")
    putLine(2, ItemApi.stone)
    move("forward")
    put("bottom", ItemApi.moss)
    move("forward")
    putLine(3, ItemApi.stone)
    uturn("right")
    putLine(2, ItemApi.stone)
    move("forward", 2)
    putLine(3, ItemApi.stone)
    uturn("left")
    putLine(6, ItemApi.stone)
    uturn("right")
    putLine(6, ItemApi.stone)
end

local function buildCompostersAndHoppers()
    if not TurtleApi.isSimulating() then
        print("[place] composter + hoppers")
    end

    move("up")
    turn("left")
    move("forward", 2)
    move("down", 5)
    move("back", 3)
    turn("left")
    move("forward", 2)
    turn("left")
    put("front", ItemApi.hopper)
    turn("left")
    move("forward", 2)
    turn("right")
    move("forward")
    turn("right")

    for i = 1, 4 do
        put("front", ItemApi.hopper)

        if i ~= 4 then
            move("back")
        end
    end

    turn("left")
    move("forward", 2)
    uturn("right")
    put("front", ItemApi.hopper)
    move("up")
    turn("back")

    -- making sure we do not load from shulker during hopper placement, as the hoppers will suck items from the shulker
    TurtleApi.selectItem(ItemApi.composter)

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", true)
    end

    move("back", 2)
    put("front", ItemApi.composter)
    turn("left")

    for _ = 1, 3 do
        move("back")
        put("front", ItemApi.composter)
    end

    turn("back")
    put("front", ItemApi.composter)
    turn("right")
    move("back")
    put("front", ItemApi.composter)

    if not TurtleApi.isSimulating() then
        redstone.setOutput("bottom", false)
    end
end

local function buildDropperRedstone()
    move("back")
    move("down", 2)
    strafe("left")
    put("front", ItemApi.hopper)
    move("up")
    put("bottom", ItemApi.smoothStone)
    move("up")
    turn("back")
    put("bottom", ItemApi.comparator)
    move("forward")
    put("bottom", ItemApi.smoothStone)
    turn("left")
    move("forward")
    move("down")
    turn("left")
    putLine(2)
    move("forward")
    put("bottom", ItemApi.redstoneTorch)
    move("up")

    for _ = 1, 2 do
        move("back")
        put("bottom", ItemApi.redstone)
    end
end

return function()
    if TurtleApi.isSimulating() then
        TurtleApi.recordPlacedBlock(ItemApi.waterBucket, 2)
        TurtleApi.recordPlacedBlock(ItemApi.lavaBucket, 1)
        TurtleApi.recordPlacedBlock(ItemApi.boneMeal, 64)
    end

    local restoreBreakable = TurtleApi.setBreakable(function()
        return true
    end)

    placeCollectorChest()
    placeDroppersAndDispenser()
    placeObserver()
    placeRedstonePathToFloodGates()
    placeWaterReservoir()
    placeFurnaceWall()
    placeWaterItemCollection()
    placeFloor()
    buildPistonSystem()
    buildPistonFluidsWall()
    buildStoneFloor()
    buildCompostersAndHoppers()
    buildDropperRedstone()
    restoreBreakable()
end
