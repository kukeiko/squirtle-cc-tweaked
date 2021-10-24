package.path = package.path .. ";/?.lua"

local Kiwi = require "kiwi"
local Inventory = require "kiwi.turtle.inventory"
local Fuel = require "kiwi.core.fuel"
local Peripheral = require "kiwi.core.peripheral"
local refuelFromInventory = require "kiwi.turtle.refuel.from-inventory"
local Side = Kiwi.Side
local inspect = Kiwi.Turtle.inspect
local move = Kiwi.Turtle.move
local turn = Kiwi.Turtle.turn
local dig = Kiwi.Turtle.dig

local cropsToSeedsMap = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:carrots"] = "minecraft:carrot"
}

local cropsReadyAges = {
    ["minecraft:wheat"] = 7,
    ["minecraft:beetroots"] = 3,
    ["minecraft:potatoes"] = 7,
    ["minecraft:carrots"] = 7
}

---@param block KiwiBlock
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

local function tryPlantAnything()
    for slot = 1, Inventory.size() do
        if Inventory.selectSlotIfNotEmpty(slot) then
            if turtle.placeDown() then
                return
            end
        end
    end
end

---@param crops string
local function selectSlotWithSeedsOfCrop(crops)
    local seeds = cropsToSeedsMap[crops]

    if not seeds then
        return false
    end

    for slot = 1, Inventory.size() do
        local stack = Inventory.getStack(slot)

        if stack and stack.name == seeds then
            return Inventory.selectSlot(slot)
        end
    end

    return false
end

---@param block KiwiBlock
---@return boolean
local function isCrops(block)
    return block.tags["minecraft:crops"]
end

---@param crops KiwiBlock
---@return integer
local function getCropsRemainingAge(crops)
    local readyAge = cropsReadyAges[crops.name]

    if not readyAge then
        error(string.format("no ready age known for %s", crops.name))
    end

    return readyAge - crops.state.age
end

local function faceFirstCrop()
    for _ = 1, 4 do
        local block = inspect()

        if block and isCrops(block) then
            return true
        end
        -- [todo] try to place a crop, maybe we have a dirt block in front that lost its crop

        turn(Side.left)
    end

    error("failed to find first crop")
end

local function faceOutputChest()
    for _ = 1, 4 do
        local chest = inspect(Side.front)

        if chest and chest.name == "minecraft:chest" then
            return true
        end

        turn(Side.left)
    end

    error("could not find output chest")
end

local function faceInputBarrel()
    for _ = 1, 4 do
        local chest = inspect(Side.front)

        if chest and chest.name == "minecraft:barrel" then
            return true
        end

        turn(Side.left)
    end

    error("could not find input barrel")
end

---@param side integer
---@param max? integer if supplied, only wait if age difference does not exceed max
local function waitUntilCropReady(side, max)
    local block = inspect(side)

    if not block or not isCrops(block) then
        error(string.format("expected block at %s to be crops", Side.getName(side)))
    end

    local remainingAge = getCropsRemainingAge(block)

    if max and remainingAge > max then
        return false
    end

    while remainingAge > 0 do
        print(string.format("waiting for crop to grow, current: %d", remainingAge))
        os.sleep(3)
        block = inspect(side)

        if not block or not isCrops(block) then
            error(string.format("crops at %s unexpectedly got replaced", Side.getName(side)))
        end

        remainingAge = getCropsRemainingAge(block)
    end

    return true
end

local function doHomeStuff()
    print("i am home! doing home stuff...")
    faceOutputChest()
    print("dumping goodies...")
    for slot = 1, 16 do
        if Inventory.selectSlotIfNotEmpty(slot) then
            if not Fuel.isFuel(Inventory.getStack(slot)) then
                -- [todo] use kiwi
                turtle.drop()
            end
        end
    end

    -- [todo] ensure minimal fuel level
    print("refueling...")
    faceInputBarrel()
    while turtle.suck() do
    end
    refuelFromInventory()

    -- print("(sleep 3s to simulate home stuff)")
    -- os.sleep(3)
    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropReady(Side.front)
    move(Side.top)
end

local function moveNext()
    while not move() do
        local block = inspect()

        if not block then
            print("could not move even though front seems to be free. sleeping 1s ...")
            os.sleep(1)
        end

        turn(getBlockTurnSide(block))
        -- if block and block.name == "minecraft:spruce_fence" then
        --     turn(Side.left)
        -- elseif block and block.name == "minecraft:oak_fence" then
        --     turn(Side.right)
        -- else
        --     if math.random() < .5 then
        --         turn(Side.left)
        --     else
        --         turn(Side.right)
        --     end
        -- end
    end
end
-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    while true do
        local block = inspect(Side.bottom)

        if block and block.name == "minecraft:chest" then
            move(Side.back)
            move(Side.bottom)
            local floor = inspect(Side.bottom)

            if not floor or floor.name ~= "minecraft:barrel" then
                error("expected to find home")
            end

            doHomeStuff()
        elseif block and block.name == "minecraft:barrel" then
            -- [todo] should only check for horizontal sides
            local chest = Peripheral.wrapOne({"minecraft:chest"})

            if not chest then
                if not move(Side.back) then
                    error("could not back down from input barrel")
                end
                if not move(Side.bottom) then
                    error("could not back down from input barrel")
                end

                local floor = inspect(Side.bottom)

                if not floor or floor.name ~= "minecraft:barrel" then
                    error("expected to find home after backing down from input barrel")
                end
            end
            doHomeStuff()
        elseif block and block.name == "minecraft:spruce_fence" then
            turn(Side.left)
        elseif block and block.name == "minecraft:oak_fence" then
            turn(Side.right)
        elseif block and isCrops(block) then
            if waitUntilCropReady(Side.bottom, 2) then
                local selectedSeed = selectSlotWithSeedsOfCrop(block.name)

                if not selectedSeed then
                    Inventory.selectFirstEmptySlot()
                    -- [todo] error handling
                end

                dig(Side.bottom)
                -- [todo] use kiwi
                turtle.placeDown()
            end
        elseif not block then
            turtle.digDown()
            tryPlantAnything()
        end

        moveNext()
    end
end

main(arg)
