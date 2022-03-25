package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

-- [todo] make the whole app crash safe

local Utils = require "utils"
local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Chest = require "world.chest"
local Furnace = require "world.furnace"
local Backpack = require "squirtle.backpack"
local Inventory = require "squirtle.inventory"
local turn = require "squirtle.turn"
local inspect = require "squirtle.inspect"
local move = require "squirtle.move"
local dig = require "squirtle.dig"
local place = require "squirtle.place"
local dump = require "squirtle.dump"
local pushOutput = require "squirtle.transfer.push-output"
local pullInput = require "squirtle.transfer.pull-input"
local suck = require "squirtle.suck"
local Fuel = require "squirtle.fuel"
local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"

local harvestTree = require "lumberjack.harvest-tree"

---@param block Block
local function getBlockTurnSide(block)
    if block.name == "minecraft:spruce_fence" then
        return Side.left
    elseif block.name == "minecraft:oak_fence" then
        return Side.right
    else
        error("block" .. block.name .. " is not a block that tells me how to turn")
    end
end

local function isHome()
    -- return inspect(Side.bottom, "minecraft:barrel") ~= nil and isHomeBarrel(Side.bottom)
    return inspect(Side.bottom, "minecraft:barrel") ~= nil
end

local function isAtWork()
    return inspect(Side.bottom, "minecraft:dirt") ~= nil
end

local function faceHomeExit()
    for _ = 1, 4 do
        local back = Peripheral.getType(Side.back)

        if back == "minecraft:furnace" then
            return
        end

        turn(Side.left)
    end

    error("could not face exit: no furnace found")
end

local function topOffFurnaceFuel(furnaceSide, bufferSide)
    local missing = Furnace.getMissingFuelCount(furnaceSide)

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:charcoal" then
            missing = missing - Furnace.pullFuel(furnaceSide, bufferSide, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

local function topOffFurnaceInput(furnaceSide, bufferSide)
    local missing = Furnace.getMissingInputCount(furnaceSide)

    for slot, stack in pairs(Chest.getStacks(bufferSide)) do
        if stack.name == "minecraft:birch_log" then
            missing = missing - Furnace.pullInput(furnaceSide, bufferSide, slot)

            if missing <= 0 then
                break
            end
        end
    end
end

-- [todo] should run until all logs everywhere are inside the furnace. turtle should not go to work with logs in the inventory
local function doFurnaceWork(furnaceSide, bufferSide)
    print("topping off furnace input...")
    topOffFurnaceInput(furnaceSide, bufferSide)

    print("pushing furnace output into buffer...")
    Furnace.pushOutput(furnaceSide, bufferSide)

    print("topping off furnace fuel...")
    topOffFurnaceFuel(furnaceSide, bufferSide)
    -- [todo] handle case where furnace has no fuel

    local fuelStack = Furnace.getFuelStack(furnaceSide)

    if not fuelStack then
        print("furnace has no fuel, pushing 1x log from input to fuel")
        Furnace.pullFuelFromInput(furnaceSide, 1)
        print("waiting for log to be turned into charcoal")

        while not Furnace.getOutputStack(furnaceSide) do
            os.sleep(1)
        end

        print("output ready! pushing to fuel...")
        Furnace.pullFuelFromOutput(furnaceSide, 1)
    end

    while Furnace.getFuelCount(furnaceSide) < 8 and Furnace.getInputStack(furnaceSide) do
        print("trying to get", 8 - Furnace.getFuelCount(furnaceSide), "more coal into fuel slot...")

        while not Furnace.getOutputStack(furnaceSide) do
            if not Furnace.getInputStack(furnaceSide) then
                print("no input to burn, exiting")
                break
            end

            os.sleep(1)
        end

        Furnace.pullFuelFromOutput(furnaceSide)
    end
end

local function doHomework()
    local bufferSide = Side.bottom
    print("i am home!")
    print("dumping inventory...")

    if not dump(bufferSide) then
        error("buffer barrel full")
    end

    local furnaceSide = Furnace.findSide()

    if not furnaceSide then
        error("no furnace connected")
    end

    doFurnaceWork(furnaceSide, bufferSide)

    if Fuel.getFuelLevel() < (64 * 80) then
        print("refueling, have", Fuel.getFuelLevel())
        Inventory.selectFirstEmptySlot()

        for slot, stack in pairs(Chest.getStacks(Side.bottom)) do
            if stack.name == "minecraft:charcoal" then
                suckSlotFromChest(Side.bottom, slot)
                Fuel.refuel() -- [todo] should provide count to not consume a whole stack
            end

            if Fuel.getFuelLevel() >= (64 * 80) then
                break
            end
        end

        print("refueled to", Fuel.getFuelLevel())

        -- in case we reached fuel limit and now have charcoal in the inventory
        if not dump(bufferSide) then
            error("buffer barrel full")
        end
    else
        print("have enough fuel:", Fuel.getFuelLevel())
    end

    local ioChestSide = Peripheral.findSide("minecraft:chest")
    print("pushing output...")
    pushOutput(bufferSide, ioChestSide)
    print("pulling input...")
    pullInput(ioChestSide, bufferSide)

    local missingCharcoal = function()
        return (Chest.getOutputMissingStock(ioChestSide)["minecraft:charcoal"] or 0)
    end

    if missingCharcoal() == 0 then
        print("waiting for output to drain...")
    end

    while missingCharcoal() == 0 do
        os.sleep(3)
    end

    print("output has space for charcoal, want to work now!")
    print("checking if we have enough input...")

    if Chest.getItemStock(bufferSide, "minecraft:bone_meal") < 64 then
        print("waiting for more bone meal...")

        while Chest.getItemStock(bufferSide, "minecraft:bone_meal") < 64 do
            os.sleep(3)
            pullInput(ioChestSide, bufferSide)
        end
    end

    print("input looks good! sucking from barrel...")

    while suck(bufferSide) do
    end

    local backpackStock = Backpack.getStock()

    if not backpackStock["minecraft:birch_sapling"] then
        error("out of birch saplings :(")
    end

    if not backpackStock["minecraft:bone_meal"] then
        error("out of bone meal :(")
    end
end

local function plantTree()
    print("planting tree...")
    move(Side.back)
    Inventory.selectItem("minecraft:birch_sapling")
    place()

    while not inspect(Side.front, "minecraft:birch_log") do
        if Inventory.selectItem("minecraft:bone_meal") then
            while place() do
            end
        else
            dig()
            move(Side.front)
            return false, "out of bone meal"
        end
    end

    return true
end

local function shouldPlantTree()
    local stock = Backpack.getStock()
    local needsMoreLogs = (stock["minecraft:birch_log"] or 0) < 64
    local hasBoneMeal = (stock["minecraft:bone_meal"] or 0) > 4
    local hasSaplings = (stock["minecraft:birch_sapling"] or 0) > 0

    return hasSaplings and needsMoreLogs and hasBoneMeal
end

local function refuelFromBackpack()
    while Fuel.getMissingFuel() > 0 and Inventory.selectItem("minecraft:stick") do
        print("refueling from sticks...")
        Fuel.refuel()
    end

    local saplingStock = Backpack.getItemStock("minecraft:birch_sapling")

    print("refueling from saplings...")
    while Fuel.getMissingFuel() > 0 and saplingStock > 64 do
        Inventory.selectItem("minecraft:birch_sapling")
        Fuel.refuel(saplingStock - 64)
        saplingStock = Backpack.getItemStock("minecraft:birch_sapling")
    end

    print("condensing backpack...")
    Inventory.condense() -- need to condense because we are not selecting saplings in reverse order (which we should)
end

local function doWork()
    print("doing work!")

    while shouldPlantTree() do
        if plantTree() then
            Inventory.selectSlot(1)
            harvestTree()
            refuelFromBackpack()
        else
            move()
            -- this case can only hit if bone meal ran out before sapling could be grown
            break
        end
    end

    dig(Side.bottom)
    move(Side.bottom)
    while suck(Side.bottom) do
    end
    refuelFromBackpack()
    move(Side.top)
    Inventory.selectItem("minecraft:dirt")
    place(Side.bottom)
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

local function main(args)
    while true do
        if isHome() then
            doHomework()
            faceHomeExit()
            move()
        elseif isAtWork() then
            doWork()
            turn(Side.left)
            move()
        else
            while not inspect(Side.bottom, {"minecraft:dirt", "minecraft:barrel"}) do
                moveNext()
            end
        end
    end
end

return main(arg)
