local Backpack = require "squirtle.backpack"
local Chest = require "world.chest"
local drop = require "squirtle.drop"
local dump = require "squirtle.dump"
local Fuel = require "squirtle.fuel"
local getStacks = require "inventory.get-stacks"
local inspect = require "squirtle.inspect"
local isCrops = require "farmer.is-crops"
local move = require "squirtle.move"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local selectItem = require "squirtle.backpack.select-item"
local suck = require "squirtle.suck"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local turn = require "squirtle.turn"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"
local SquirtleV2 = require "squirtle.squirtle-v2"

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
    while SquirtleV2.select("seeds") do
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

return function()
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
