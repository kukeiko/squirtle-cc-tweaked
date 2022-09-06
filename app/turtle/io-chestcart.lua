package.path = package.path .. ";/lib/?.lua"

local findPeripheralSide = require "world.peripheral.find-side"
local Chest = require "world.chest"
local Redstone = require "world.redstone"
local Inventory = require "squirtle.inventory"
local pushInput = require "squirtle.transfer.push-input"
local pullOutput = require "squirtle.transfer.pull-output"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local turn = require "squirtle.turn"
local inspect = require "squirtle.inspect"
local suck = require "squirtle.suck"
local dump = require "squirtle.dump"
local place = require "squirtle.place"
local dig = require "squirtle.dig"
local subtractStock = require "world.chest.subtract-stock"
local count = require "utils.count"

local function findChestSide()
    return findPeripheralSide("minecraft:chest")
end

local function dumpChestcartToBarrel()
    while suck() do
    end

    if not dump("bottom") then
        error("buffer barrel full")
    end

    if suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while suck("bottom") do
    end

    if not dump("front") then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if suck("bottom") then
        dumpBarrelToChestcart()
    end
end

local function waitForChestcart()
    os.sleep(1)
    if not Inventory.selectItem("minecraft:redstone_block") then
        error("my redstone block went missing :(")
    end

    print("waiting for chestcart...")
    os.pullEvent("redstone")
    print("chestcart is here! locking it in place...")

    if not place() then
        error("could not place redstone block to lock piston :(")
    end
end

local function lookAtChestcart()
    local signal = Redstone.getInput({"left", "right"})

    if signal then
        -- turn towards the chestcart
        turn(signal)
    else
        -- unlock piston in case there is no chestcart
        dig()
    end
end

local function emptyChestcart()
    if not Redstone.getInput("front") then
        print("looking at rail, but no chestcart here. turning towards piston")
        local chest = findChestSide()

        if chest == "left" then
            turn("right")
        else
            turn("left")
        end
    else
        dumpChestcartToBarrel()
        local chest = findChestSide()
        turn(chest)
    end
end

local function doIO()
    print("doing I/O...")
    local io = findChestSide()

    -- [todo] need to somehow support 27+ slot chests
    if sendOutput then
        pushInput("bottom", io)
        pullOutput(io, "bottom", Chest.getInputOutputMaxStock(io))
    else
        local _, transferredStock = pushOutput("bottom", io)
        local movedAnyOutput = count(transferredStock) > 0
        local maxStock = subtractStock(Chest.getInputOutputMaxStock(io), transferredStock)
        local transferredInputStock = pullInput(io, "bottom", maxStock)
        local movedAnyInput = count(transferredInputStock) > 0

        if not movedAnyInput and not movedAnyOutput then
            print("didn't transfer anything, sleeping 7s")
            os.sleep(7)
        end
    end

    local signal = Redstone.getInput({"left", "right"})
    turn(signal)
    print("filling chestcart...")
    dumpBarrelToChestcart()
    print("sending off chestcart!")
    turn(signal)
    dig()
    os.sleep(3)
end

---@param args table
---@return boolean success
local function main(args)
    print("[io-chestcart v1.3.0] booting...")

    if not inspect("bottom", "minecraft:barrel") then
        error("no barrel at bottom")
    end

    if args[1] == "send-output" then
        sendOutput = true
    elseif args[1] == "send-input" then
        sendOutput = false
    else
        sendOutput = false
    end

    while true do
        local front = inspect()

        if front and front.name == "minecraft:redstone_block" then
            lookAtChestcart();
        elseif front and front.name == "minecraft:detector_rail" then
            emptyChestcart()
        elseif front and front.name == "minecraft:chest" then
            doIO();
        elseif not front and findChestSide() == "back" then
            waitForChestcart()
        end
    end
end

return main(arg)
