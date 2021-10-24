package.path = package.path .. ";/?.lua"

local Utils = require "kiwi.utils"
local Side = require "kiwi.core.side"
local Peripheral = require "kiwi.core.peripheral"
local Fuel = require "kiwi.core.fuel"
local Inventory = require "kiwi.turtle.inventory"
local inspect = require "kiwi.turtle.inspect"
local turn = require "kiwi.turtle.turn"

-- barrel redstone signal being off means we activated the hopper, which we only do when:
--  - we're unloading items to be dispatched into the chestcart
--  - we were checking to see if there is a chestcart beneath the turtle, waiting
-- we first need to unload all the coal we need (last line of inventory of shared chest is reserved for input, if full, dont take more from chestcart
-- so that the dispatcher on the other side sees there is still some untaken coal, which means it should not send any more for now maybe?)
local function usage()
    print("usage:")
    print("chestcart-dispatcher in|out")
    return false
end

local function faceDetectorRail()
    for _ = 1, 4 do
        local block = inspect()

        if block and block.name == "minecraft:detector_rail" then
            return true
        end

        turn(Side.left)
    end

    error("no detector rail found")
end

local function wrapChest()
    local chest, side = Peripheral.wrapOne({"minecraft:chest"})

    if not chest then
        error("no chest found")
    end

    return chest, side
end

local function dumpInventoryToBarrel()
    for slot = 1, 16 do
        if Inventory.selectSlotIfNotEmpty(slot) then
            -- [todo] use kiwi
            if not turtle.dropDown() then
                error(
                    "could not move item from inventory into barrel while trying to dump inventory")
            end
        end
    end
end

local function emptyCart()
    if not Inventory.moveFirstSlotSomewhereElse() then
        error("can't empty cart, inventory full")
    end

    Inventory.selectSlot(1)

    -- [todo] use kiwi
    while turtle.suck() do
        if not turtle.dropDown() then
            error("could not move item from inventory into barrel while trying to empty the cart")
        end
    end
end

---@param from integer
---@param to integer
local function transferFuel(from, to, level)
    local fromChest = Peripheral.wrap(from)
    local toChest = Peripheral.wrap(to)
    local currentFuel = Fuel.sumFuel(toChest.list())

    print("current fuel", currentFuel)
    if currentFuel < level then
        local missing = level - currentFuel
        print(string.format("target chest is missing %d fuel", missing))
        local pickedStacks = Fuel.pickStacks(fromChest.list(), missing, 80)

        for slot, stack in pairs(pickedStacks) do
            fromChest.pushItems(Side.getName(to), slot)
        end
    end
end

---@param from integer
---@param to integer
local function transferGoods(from, to)
    local chest = Peripheral.wrap(from)
    for slot, stack in pairs(chest.list()) do
        if not Fuel.isFuel(stack.name) then
            chest.pushItems(Side.getName(to), slot)
        end
    end
end

local function fillCart()
    while turtle.suckDown() do
        while Inventory.selectFirstOccupiedSlot() do
            while turtle.drop() do
            end
        end
    end
end

local function dispatch()
    redstone.setOutput("right", false)
    os.sleep(2)
    redstone.setOutput("right", true)
end

local function main(args)
    local isOutput

    -- [todo] remove
    if not args[1] then
        args[1] = "out"
    end

    if args[1] == "in" then
        isOutput = false
    elseif args[1] == "out" then
        isOutput = true
    else
        return usage()
    end

    faceDetectorRail()

    local pistonPedestalSide = "right"

    if not isOutput then
        pistonPedestalSide = "left"
    end

    -- extend piston in case unexpected shutdown happened during chestcart dispatch
    redstone.setOutput(pistonPedestalSide, true)

    -- if we have items in inventory, we were either loading or unloading the chestcart.
    -- therefore move back to barrel
    dumpInventoryToBarrel()

    local targetFuelLevel = 160

    while true do
        if redstone.getInput("front") then
            emptyCart()
            local _, chestSide = wrapChest()

            if isOutput then
                transferFuel(Side.bottom, chestSide, targetFuelLevel)
                transferGoods(chestSide, Side.bottom)
                fillCart()
            else
                transferGoods(Side.bottom, chestSide)

                if Peripheral.getType(Side.top) == "minecraft:chest" then
                    transferFuel(Side.top, Side.bottom, targetFuelLevel)
                else
                    transferFuel(chestSide, Side.bottom, targetFuelLevel)
                end
                fillCart()
            end
            redstone.setOutput(pistonPedestalSide, false)
            os.sleep(2)
            redstone.setOutput(pistonPedestalSide, true)
        end

        os.pullEvent("redstone")
        print("received redstone signal!")
        -- os.sleep(3)
    end
end

return main(arg)
