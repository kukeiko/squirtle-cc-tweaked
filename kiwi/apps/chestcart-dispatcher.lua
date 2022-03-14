package.path = package.path .. ";/?.lua"

local Utils = require "kiwi.utils"
local Side = require "kiwi.core.side"
local Peripheral = require "kiwi.core.peripheral"
local Fuel = require "kiwi.core.fuel"
local Inventory = require "kiwi.turtle.inventory"
local inspect = require "kiwi.turtle.inspect"
local turn = require "kiwi.turtle.turn"

---@class KiwiChestcartDispatcherSettings

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

local function facePistonPedestal()
    local chest, chestSide = Peripheral.wrapOne({"minecraft:chest", Side.horizontal()})

    if not chest then
        print("can't face piston pedestal: chest not found")
    end

    if chestSide == Side.front then
        -- return
    elseif chestSide == Side.back then
        return true
    elseif chestSide == Side.left then
        return turn(Side.right)
    elseif chestSide == Side.right then
    end
end

-- [todo] unfinished, not sure how to do it yet
local function ifHasModemEquipToCorrectSide()
    local left, right = Peripheral.getType(Side.left), Peripheral.getType(Side.right)

    if left == "modem" or right == "modem" then
        -- we have a modem to the left but still found the chest - no switch necessary
        if Peripheral.wrapOne({"minecraft:chest"}, Side.horizontal) then
            return false
        end
    end
end

local function main(args)
    local isOutput

    if args[1] == "in" then
        isOutput = false
    elseif args[1] == "out" then
        isOutput = true
    else
        return usage()
    end

    local bottom = inspect(Side.bottom)

    if not bottom or bottom.name ~= "minecraft:barrel" then
        error("no barrel @ bottom")
    end

    faceDetectorRail()

    local left, right = Peripheral.getType(Side.left), Peripheral.getType(Side.right)
    local chestSide, pistonPedestalSide

    if left == "minecraft:chest" then
        chestSide = Side.left
        pistonPedestalSide = Side.right
    elseif right == "minecraft:chest" then
        chestSide = Side.right
        pistonPedestalSide = Side.left
    else
        error("no chest to either left or the right")
    end

    redstone.setOutput(Side.getName(pistonPedestalSide), true)
    -- only front will be false, so that piston is extended if we're not looking at it
    -- redstone.setOutput("left", true)
    -- redstone.setOutput("right", true)
    redstone.setOutput("back", true)

    turn(pistonPedestalSide)

    local targetFuelLevel = 160

    while true do
        os.pullEvent("redstone")
        if redstone.getInput(Side.getName(chestSide)) then
            print("cart is here! emptying it out...")
            turn(chestSide)
            emptyCart()

            if isOutput then
                turn(chestSide)
                transferFuel(Side.bottom, Side.front, targetFuelLevel)
                transferGoods(Side.front, Side.bottom)
                turn(pistonPedestalSide)
                fillCart()
            else
                turn(chestSide)
                transferGoods(Side.bottom, Side.front)

                if Peripheral.getType(Side.top) == "minecraft:chest" then
                    transferFuel(Side.top, Side.bottom, targetFuelLevel)
                else
                    transferFuel(Side.front, Side.bottom, targetFuelLevel)
                end

                turn(pistonPedestalSide)
                fillCart()
            end

            print("dispatching")
            turn(pistonPedestalSide)
            -- need to sleep a bit, otherwise we will pull our own redstone signal
            os.sleep(2)
        end
    end
end

return main(arg)
