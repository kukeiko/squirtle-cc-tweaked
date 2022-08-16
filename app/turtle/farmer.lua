package.path = package.path .. ";/lib/?.lua"

-- [todo] did some changes that might no longer make this app 100% crash safe
local Inventory = require "squirtle.inventory"
local Fuel = require "squirtle.fuel"
local Peripheral = require "world.peripheral"
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

---@param block Block
---@return boolean
local function isCrops(block)
    return block.tags["minecraft:crops"]
end

---@param crops Block
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

        turn("left")
    end

    error("failed to find first crop")
end

---@param side string
local function isCropsReady(side)
    local block = inspect(side)

    if not block or not isCrops(block) then
        error(string.format("expected block at %s to be crops", side))
    end

    return getCropsRemainingAge(block) == 0
end

---@param side string
---@param max? integer if supplied, only wait if age difference does not exceed max
local function waitUntilCropReady(side, max)
    while not isCropsReady(side) and Inventory.selectItem("minecraft:bone_meal") do
        while place(side) do
        end
    end

    local block = inspect(side)

    if not block or not isCrops(block) then
        error(string.format("expected block at %s to be crops", side))
    end

    local remainingAge = getCropsRemainingAge(block)

    if max and remainingAge > max then
        return false
    end

    while remainingAge > 0 do
        print(string.format("waiting for crop to grow, current: %d", remainingAge))
        os.sleep(30)
        block = inspect(side)

        if not block or not isCrops(block) then
            error(string.format("crops at %s unexpectedly got replaced", side))
        end

        remainingAge = getCropsRemainingAge(block)
    end

    return true
end

---@param bufferSide integer
---@param fuel integer
local function refuelFromBuffer(bufferSide, fuel)
    print("refueling, have", Fuel.getFuelLevel())
    Inventory.selectFirstEmptySlot()

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:charcoal" then
            suckSlotFromChest(bufferSide, slot)
            Fuel.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if Fuel.getFuelLevel() >= fuel then
            break
        end
    end

    print("refueled to", Fuel.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not dump(bufferSide) then
        error("buffer barrel full")
    end
end

local function compostSeeds()
    while Inventory.selectItem("seeds") do
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

local function doHomeStuff()
    local barrel = "bottom"
    print("i am home! doing home stuff")

    while Inventory.selectItem("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        drop("top")
    end

    if not dump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds
    local ioChest = Chest.findSide()
    print("pushing output once")
    pushOutput(barrel, ioChest)

    -- then we're gonna compost
    move("back")

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
    end

    local minFuel = 512
    local ioChest = Chest.findSide()

    print("pushing output...")

    while not pushOutput(barrel, ioChest) do
        os.sleep(3)
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

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(Inventory.list()) do
        if stack.name == "minecraft:charcoal" then
            Inventory.selectSlot(slot)
            drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropReady("front")
    move("top")
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

-- the only way for the turtle to find home is to find a chest at bottom,
-- at which point the turtle will move back and then down. it'll then
-- expect there to be a barrel - otherwise errors out.
-- this strict requirement makes it so that we never have to move down
-- a block to check if we reached home, which is gud.
---@param args table
local function main(args)
    while true do
        local block = inspect("bottom")

        if block and block.name == "minecraft:chest" then
            move("back")
            move("bottom")
            local floor = inspect("bottom")

            if not floor or floor.name ~= "minecraft:barrel" then
                error("expected to find home")
            end

            doHomeStuff()
        elseif block and block.name == "minecraft:barrel" then
            -- [todo] should only check for horizontal sides
            local chest = Peripheral.wrapOne({"minecraft:chest"})

            -- [todo] there no longer is a dedicated input barrel, but an io-chest instead,
            -- so should just error out, complaining that there is no io-chest.
            if not chest then
                -- [todo] there no longer is an input barrel
                if not move("back") then
                    error("could not back down from input barrel")
                end

                if not move("bottom") then
                    error("could not back down from input barrel")
                end

                local floor = inspect("bottom")

                if not floor or floor.name ~= "minecraft:barrel" then
                    error("expected to find home after backing down from input barrel")
                end
            end

            doHomeStuff()
        elseif block and block.name == "minecraft:composter" then
            print("crashed while composting!")
            -- [todo] moving to barrel cause im lazy right now,
            -- the home routing will initiate composting
            move()
        elseif block and block.name == "minecraft:spruce_fence" then
            turn("left")
        elseif block and block.name == "minecraft:oak_fence" then
            turn("right")
        elseif block and isCrops(block) then
            if waitUntilCropReady("bottom", 2) then
                local selectedSeed = selectSlotWithSeedsOfCrop(block.name)

                if not selectedSeed then
                    Inventory.selectFirstEmptySlot()
                    -- [todo] error handling
                end

                dig("bottom")

                if not place("bottom") then
                    tryPlantAnything()
                end
            end
        elseif not block then
            turtle.digDown()
            tryPlantAnything()
        end

        moveNext()
    end
end

main(arg)
