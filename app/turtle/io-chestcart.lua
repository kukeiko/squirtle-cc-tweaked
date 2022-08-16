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

local function printUsage()
    print("Usage:")
    print("io-chestcart send-output|send-input")
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
        printUsage()
        return false
    end

    while true do
        local front = inspect()

        if front and front.name == "minecraft:redstone_block" then
            local signal = Redstone.getInput({"left", "right"})

            if signal then
                turn(signal)
            else
                -- unlock piston in case there is no chestcart
                dig()
            end
        elseif front and front.name == "minecraft:detector_rail" then
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
        elseif front and front.name == "minecraft:chest" then
            print("doing I/O...")
            local io = findChestSide()

            -- [todo] need to somehow support 27+ slot chests
            if sendOutput then
                pushInput("bottom", io)
                pullOutput(io, "bottom", Chest.getInputOutputMaxStock(io))
            else
                local _, transferredStock = pushOutput("bottom", io)
                local maxStock = subtractStock(Chest.getInputOutputMaxStock(io), transferredStock)
                pullInput(io, "bottom", maxStock)
            end

            local signal = Redstone.getInput({"left", "right"})
            turn(signal)
            print("filling chestcart...")
            dumpBarrelToChestcart()
            print("sending off chestcart!")
            turn(signal)
            dig()
            os.sleep(3)
        elseif not front and findChestSide() == "back" then
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
    end
end

return main(arg)
