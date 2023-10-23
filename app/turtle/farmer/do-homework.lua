local Squirtle = require "squirtle"
local Inventory = require "inventory.inventory"
local isCrops = require "farmer.is-crops"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"

---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", Squirtle.getFuelLevel())
    Squirtle.selectFirstEmptySlot()

    for slot, stack in pairs(Inventory.getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            Squirtle.suckSlotFromChest(buffer, slot)
            Squirtle.refuelSlot() -- [todo] should provide count to not consume a whole stack
        end

        if Squirtle.getFuelLevel() >= fuel then
            break
        end
    end

    print("refueled to", Squirtle.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not Squirtle.dump(buffer) then
        error("buffer barrel full")
    end
end

local function compostSeeds()
    while Squirtle.select("seeds") do
        Squirtle.drop("bottom")
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
        local block = Squirtle.inspect()

        if block and isCrops(block) then
            return true
        end
        -- [todo] try to place a crop, maybe we have a dirt block in front that lost its crop

        Squirtle.left()
    end

    error("failed to find first crop")
end

return function()
    local ioChest = Inventory.findChest()
    local barrel = "bottom"

    if not ioChest then
        error("no I/O chest found")
    end

    Squirtle.turn(ioChest)
    ioChest = "front"
    print("i am home! doing home stuff")

    if not Squirtle.dump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds or poisonous taters
    print("pushing output once")
    Squirtle.pushOutput(barrel, ioChest)

    local minFuel = 512
    print("pushing output...")

    while not Squirtle.pushOutput(barrel, ioChest) do
        os.sleep(7)
    end

    while Squirtle.getFuelLevel() < minFuel do
        print("trying to refuel to ", minFuel, ", have", Squirtle.getFuelLevel())
        Squirtle.pullInput(ioChest, barrel)
        refuelFromBuffer(barrel, minFuel)

        if Squirtle.getFuelLevel() < minFuel then
            os.sleep(3)
        end
    end

    print("pulling input...")
    Squirtle.pullInput(ioChest, barrel)

    print("sucking barrel...")
    while Squirtle.suck(barrel) do
    end

    -- then we're gonna compost and drop any unwanted poisonous taters
    Squirtle.back()

    while Squirtle.select("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        Squirtle.drop("top")
    end

    -- [todo] possible optimization: only move to composter if we have seeds
    if not Squirtle.inspect("bottom", "minecraft:composter") then
        print("no composter, going back to barrel")
        Squirtle.forward()
    else
        print("composting seeds")
        compostSeeds()
        Squirtle.forward()
        print("draining dropper")
        drainDropper()
        while Squirtle.suck(barrel) do
        end
    end

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(Squirtle.getStacks()) do
        if stack.name == "minecraft:charcoal" then
            Squirtle.selectSlot(slot)
            Squirtle.drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropsReady("front", 2, (7 * 3) + 1)
    Squirtle.up()
end
