package.path = package.path .. ";/?.lua"

local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Inventory = require "squirtle.inventory"
local turn = require "squirtle.turn"
local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local dig = require "squirtle.dig"

local lumberjackBits = {planting = 1, harvesting = 2}

function indexOf(tbl, item)
    for i = 1, #tbl do
        if (tbl[i] == item) then
            return i
        end
    end

    return -1
end

---@param block Block
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return Side.left
    elseif block.name == "minecraft:oak_fence" then
        return Side.right
    else
        if math.random() < .5 then
            return Side.left
        else
            return Side.right
        end
    end
end

local function isHome()
    return (inspect(Side.bottom) or {}).name == "minecraft:barrel"
end

local function isAtWork()
    return (inspect(Side.bottom) or {}).name == "minecraft:chest"
end

local function faceExit()
    for _ = 1, 4 do
        local back = Peripheral.getType(Side.back)

        if back == "minecraft:barrel" then
            return
        end

        turn(Side.left)
    end

    error("could not face exit: no barrel found")
end

local function doHomework()
    print("doing home work! (3s)")
    os.sleep(3)
end

local function doWork()
    print("doing work!")
    Inventory.selectItem("minecraft:dirt")
    move(Side.top)
    turtle.placeDown() -- [todo] use squirtle
    Inventory.selectItem("minecraft:birch_sapling")
    move(Side.back)
    turtle.place()
    Inventory.selectItem("minecraft:bone_meal")

    while turtle.place() do
    end

    dig()
    move()

    while inspect(Side.top) do
        dig(Side.top)
        move(Side.top)
    end

    while move(Side.bottom) do
    end

    dig(Side.bottom)
    move(Side.bottom)
    print("work finished! going home")
end

local function moveNext()
    while not move() do
        local block = inspect()

        if not block then
            print("could not move even though front seems to be free. sleeping 1s ...")
            os.sleep(1)
        end

        turn(getBlockTurnSide(block))
    end
end

---@param goal string|table
local function travel(goal)
    if type(goal) == "string" then
        goal = {goal}
    end

    while indexOf(goal, (inspect(Side.bottom) or {}).name) < 0 do
        moveNext()
    end
end

local function main(args)
    while true do
        if isHome() then
            doHomework()
            faceExit()
            move()
        elseif isAtWork() then
            doWork()
            turn(Side.left)
            move()
        else
            travel({"minecraft:chest", "minecraft:barrel"})
        end
    end
end

return main(arg)
