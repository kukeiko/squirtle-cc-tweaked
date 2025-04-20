local TurtleApi = require "lib.apis.turtle.turtle-api"
local Inventory = require "lib.apis.inventory.inventory-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local isCrops = require "farmer.is-crops"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"

---@param buffer string
---@param fuel integer
local function refuelFromBuffer(buffer, fuel)
    print("refueling, have", TurtleApi.getFuelLevel())
    TurtleApi.selectFirstEmpty()

    for slot, stack in pairs(InventoryPeripheral.getStacks(buffer)) do
        if stack.name == "minecraft:charcoal" then
            TurtleApi.suckSlot(buffer, slot)
            TurtleApi.refuel() -- [todo] should provide count to not consume a whole stack
        end

        if TurtleApi.hasFuel(fuel) then
            break
        end
    end

    print("refueled to", TurtleApi.getFuelLevel())

    -- in case we reached fuel limit and now have charcoal in the inventory
    if not TurtleApi.tryDump(buffer) then
        error("buffer barrel full")
    end
end

local function compostSeeds()
    while TurtleApi.selectItem("seeds") do
        TurtleApi.drop("bottom")
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
        local block = TurtleApi.probe()

        if block and isCrops(block) then
            return true
        end
        -- [todo] try to place a crop, maybe we have a dirt block in front that lost its crop

        TurtleApi.turn("left")
    end

    error("failed to find first crop")
end

return function()
    local ioChest = Inventory.findChest()
    local barrel = "bottom"
    TurtleApi.turn(ioChest)
    ioChest = "front"
    print("i am home! doing home stuff")

    if not TurtleApi.tryDump(barrel) then
        error("buffer barrel full :(")
    end

    -- first we make a single pushOutput() in case output wants seeds or poisonous taters
    print("pushing output once")
    TurtleApi.pushOutput(barrel, ioChest)
    print("pushing output...")
    TurtleApi.pushAllOutput(barrel, ioChest)

    local minFuel = 512

    while not TurtleApi.hasFuel(minFuel) do
        print("trying to refuel to", minFuel, "have", TurtleApi.getFuelLevel())
        TurtleApi.pullInput(ioChest, barrel)
        refuelFromBuffer(barrel, minFuel)

        if not TurtleApi.hasFuel(minFuel) then
            os.sleep(3)
        end
    end

    print("pulling input...")
    TurtleApi.pullInput(ioChest, barrel)

    print("sucking barrel...")
    while TurtleApi.suck(barrel) do
    end

    -- then we're gonna compost and drop any unwanted poisonous taters
    TurtleApi.walk("back")

    while TurtleApi.selectItem("minecraft:poisonous_potato") do
        print("discarding poisonous potatoes")
        TurtleApi.drop("up")
    end

    -- [todo] possible optimization: only move to composter if we have seeds
    if not TurtleApi.probe("down", "minecraft:composter") then
        print("no composter, going back to barrel")
        TurtleApi.walk("forward")
    else
        print("composting seeds")
        compostSeeds()
        TurtleApi.walk("forward")
        print("draining dropper")
        drainDropper()
        while TurtleApi.suck(barrel) do
        end
    end

    -- [todo] hacky workaround to put back charcoal
    for slot, stack in pairs(TurtleApi.getStacks()) do
        if stack.name == "minecraft:charcoal" then
            TurtleApi.select(slot)
            TurtleApi.drop(barrel)
        end
    end

    print("home stuff ready!")
    faceFirstCrop()
    waitUntilCropsReady("front", 2, (7 * 3) + 1)
    TurtleApi.walk("up")
end
