local Squirtle = require "lib.squirtle.squirtle-api"
local Inventory = require "lib.apis.inventory-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local isCrops = require "farmer.is-crops"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"

---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", Squirtle.getFuelLevel())
    Squirtle.selectFirstEmpty()

    for slot, stack in pairs(InventoryPeripheral.getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            Squirtle.suckSlot(buffer, slot)
            Squirtle.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if Squirtle.hasFuel(fuel) then
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
    while Squirtle.selectItem("seeds") do
        Squirtle.drop("bottom")
    end
end

local function drainDropper()
    repeat
        local totalItemStock = Inventory.getTotalItemCount({"bottom"}, "buffer")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
    until Inventory.getTotalItemCount({"bottom"}, "buffer") == totalItemStock
end

local function faceFirstCrop()
    for _ = 1, 4 do
        local block = Squirtle.probe()

        if block and isCrops(block) then
            return true
        end
        -- [todo] try to place a crop, maybe we have a dirt block in front that lost its crop

        Squirtle.turn("left")
    end

    error("failed to find first crop")
end

return function()
    local ioChest = Inventory.findChest()
    local barrel = "bottom"
    Squirtle.turn(ioChest)
    ioChest = "front"
    print("i am home! doing home stuff")

    if not Squirtle.dump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds or poisonous taters
    print("pushing output once")
    Squirtle.pushOutput(barrel, ioChest)
    print("pushing output...")
    Squirtle.pushAllOutput(barrel, ioChest)

    local minFuel = 512

    while not Squirtle.hasFuel(minFuel) do
        print("trying to refuel to", minFuel, "have", Squirtle.getFuelLevel())
        Squirtle.pullInput(ioChest, barrel)
        refuelFromBuffer(barrel, minFuel)

        if not Squirtle.hasFuel(minFuel) then
            os.sleep(3)
        end
    end

    print("pulling input...")
    Squirtle.pullInput(ioChest, barrel)

    print("sucking barrel...")
    while Squirtle.suck(barrel) do
    end

    -- then we're gonna compost and drop any unwanted poisonous taters
    Squirtle.walk("back")

    while Squirtle.selectItem("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        Squirtle.drop("up")
    end

    -- [todo] possible optimization: only move to composter if we have seeds
    if not Squirtle.probe("down", "minecraft:composter") then
        print("no composter, going back to barrel")
        Squirtle.walk("forward")
    else
        print("composting seeds")
        compostSeeds()
        Squirtle.walk("forward")
        print("draining dropper")
        drainDropper()
        while Squirtle.suck(barrel) do
        end
    end

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(Squirtle.getStacks()) do
        if stack.name == "minecraft:charcoal" then
            Squirtle.select(slot)
            Squirtle.drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropsReady("front", 2, (7 * 3) + 1)
    Squirtle.walk("up")
end
