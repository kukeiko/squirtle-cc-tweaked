local SquirtleV2 = require "squirtle.squirtle-v2"
local Inventory = require "inventory.inventory"

local Fuel = require "squirtle.fuel"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
local isCrops = require "farmer.is-crops"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"

---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", Fuel.getFuelLevel())
    SquirtleV2.selectFirstEmptySlot()

    for slot, stack in pairs(Inventory.getStacks(buffer)) do
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
    if not SquirtleV2.dump(buffer) then
        error("buffer barrel full")
    end
end

local function compostSeeds()
    while SquirtleV2.select("seeds") do
        SquirtleV2.drop("bottom")
    end
end

local function drainDropper()
    repeat
        local bufferCount = Inventory.countItems("bottom")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until Inventory.countItems("bottom") == bufferCount
end

local function faceFirstCrop()
    for _ = 1, 4 do
        local block = SquirtleV2.inspect()

        if block and isCrops(block) then
            return true
        end
        -- [todo] try to place a crop, maybe we have a dirt block in front that lost its crop

        SquirtleV2.left()
    end

    error("failed to find first crop")
end

return function()
    local ioChest = Inventory.findChest()
    local barrel = "bottom"

    if not ioChest then
        error("no I/O chest found")
    end

    SquirtleV2.turn(ioChest)
    ioChest = "front"
    print("i am home! doing home stuff")

    if not SquirtleV2.dump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds or poisonous taters
    print("pushing output once")
    pushOutput(barrel, ioChest)

    local minFuel = 512
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
    while SquirtleV2.suck(barrel) do
    end

    -- then we're gonna compost and drop any unwanted poisonous taters
    SquirtleV2.back()

    while SquirtleV2.select("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        SquirtleV2.drop("top")
    end

    -- [todo] possible optimization: only move to composter if we have seeds
    if not SquirtleV2.inspect("bottom", "minecraft:composter") then
        print("no composter, going back to barrel")
        SquirtleV2.forward()
    else
        print("composting seeds")
        compostSeeds()
        SquirtleV2.forward()
        print("draining dropper")
        drainDropper()
        while SquirtleV2.suck(barrel) do
        end
    end

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(SquirtleV2.getStacks()) do
        if stack.name == "minecraft:charcoal" then
            SquirtleV2.selectSlot(slot)
            SquirtleV2.drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropsReady("front", 2, (7 * 3) + 1)
    SquirtleV2.up()
end
