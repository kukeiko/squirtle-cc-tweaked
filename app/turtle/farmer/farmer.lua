package.path = package.path .. ";/lib/?.lua"

-- [todo] did some changes that might no longer make this app 100% crash safe
local Backpack = require "squirtle.backpack"
local Fuel = require "squirtle.fuel"
local Chest = require "world.chest"
local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local turn = require "squirtle.turn"
local dig = require "squirtle.dig"
local dump = require "squirtle.dump"
local pushOutput = require "squirtle.transfer.push-output"
local pullInput = require "squirtle.transfer.pull-input"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local drop = require "squirtle.drop"
local place = require "squirtle.place"
local suck = require "squirtle.suck"
local getStacks = require "inventory.get-stacks"
local selectItem = require "squirtle.backpack.select-item"

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

---@param block Block
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return "left"
    elseif block.name == "minecraft:oak_fence" then
        return "right"
    else
        if math.random() < .5 then
            return "left"
        else
            return "right"
        end
    end
end

local function tryPlantAnything()
    for slot = 1, Backpack.size() do
        if Backpack.selectSlotIfNotEmpty(slot) then
            if place("bottom") then
                return
            end
        end
    end
end

---@param crops string
---@return false|integer
local function selectSlotWithSeedsOfCrop(crops)
    local seeds = cropsToSeedsMap[crops]

    if not seeds then
        return false
    end

    return selectItem(seeds)
end

---@param block Block
---@return boolean
local function isCrops(block)
    return block.tags["minecraft:crops"]
end

---@param side string
---@return integer
local function getCropsRemainingAge(side)
    local crops = inspect(side)

    if not crops or not isCrops(crops) then
        error(string.format("expected block at %s to be crops", side))
    end

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

        turn("left")
    end

    error("failed to find first crop")
end

---@param side string
---@param max? integer if supplied, only wait if age difference does not exceed max
---@param time? integer maximum amount of time to wait
---@return boolean ready if crops are ready
local function waitUntilCropsReady(side, max, time)
    while getCropsRemainingAge(side) > 0 and selectItem("minecraft:bone_meal") and place(side) do
    end

    local remainingAge = getCropsRemainingAge(side)

    if max and remainingAge > max then
        return false
    end

    if remainingAge > 0 then
        print("waiting for crop to grow")
    end

    local waitUntilReady = function()
        while getCropsRemainingAge(side) > 0 do
            os.sleep(7)
        end
    end

    if time then
        return parallel.waitForAny(waitUntilReady, function()
            os.sleep(time)
        end) == 1
    end

    waitUntilReady()

    return true
end

---@param block Block
local function harvestCrops(block)
    if waitUntilCropsReady("bottom", 2, (7 * 3) + 1) then
        local selectedSeed = selectSlotWithSeedsOfCrop(block.name)

        if not selectedSeed then
            Backpack.selectFirstEmptySlot()
            -- [todo] error handling
        end

        dig("bottom")

        if not place("bottom") then
            tryPlantAnything()
        end
    end
end

---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", Fuel.getFuelLevel())
    Backpack.selectFirstEmptySlot()

    for slot, stack in pairs(getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            suckSlotFromChest(buffer, slot)
            Fuel.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if Fuel.getFuelLevel() >= fuel then
            break
        end
    end

    print("refueled to", Fuel.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not dump(buffer) then
        error("buffer barrel full")
    end
end

local function compostSeeds()
    while Backpack.selectItem("seeds") do
        drop("bottom")
    end
end

local function drainDropper()
    repeat
        local bufferCount = Chest.countItems("bottom")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until Chest.countItems("bottom") == bufferCount
end

local function doHomework()
    local ioChest = Chest.findSide()
    local barrel = "bottom"

    if not ioChest then
        error("no I/O chest found")
    end

    turn(ioChest)
    ioChest = "front"
    print("i am home! doing home stuff")

    if not dump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds or poisonous taters
    print("pushing output once")
    pushOutput(barrel, ioChest)

    local minFuel = 512
    local ioChest = Chest.findSide()

    print("pushing output...")

    while not pushOutput(barrel, ioChest) do
        os.sleep(7)
    end

    while Fuel.getFuelLevel() < minFuel do
        print("trying to refuel to ", minFuel, ", have", Fuel.getFuelLevel())
        pullInput(ioChest, barrel)
        refuelFromBuffer(barrel, minFuel)

        if Fuel.getFuelLevel() < minFuel then
            os.sleep(3)
        end
    end

    print("pulling input...")
    pullInput(ioChest, barrel)

    print("sucking barrel...")
    while suck(barrel) do
    end

    -- then we're gonna compost and drop any unwanted poisonous taters
    move("back")

    while selectItem("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        drop("top")
    end

    -- [todo] possible optimization: only move to composter if we have seeds
    if not inspect("bottom", "minecraft:composter") then
        print("no composter, going back to barrel")
        move()
    else
        print("composting seeds")
        compostSeeds()
        move()
        print("draining dropper")
        drainDropper()
        while suck(barrel) do
        end
    end

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(Backpack.getStacks()) do
        if stack.name == "minecraft:charcoal" then
            Backpack.selectSlot(slot)
            drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropsReady("front", 2, (7 * 3) + 1)
    move("top")
end

local function moveNext()
    while not move() do
        local block = inspect()

        if not block then
            print("could not move even though front seems to be free")

            while not block do
                os.sleep(1)
                block = inspect()
            end
        end

        turn(getBlockTurnSide(block))
    end
end

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    print("[farmer v1.3.0] booting...")

    while true do
        local block = inspect("bottom")

        if block and block.name == "minecraft:chest" then
            move("back")
            move("bottom")
        else
            if block and block.name == "minecraft:barrel" then
                doHomework()
            elseif block and block.name == "minecraft:spruce_fence" then
                turn("left")
            elseif block and block.name == "minecraft:oak_fence" then
                turn("right")
            elseif block and isCrops(block) then
                harvestCrops(block)
            elseif not block then
                turtle.digDown()
                tryPlantAnything()
            end

            moveNext()
        end
    end
end

main(arg)
