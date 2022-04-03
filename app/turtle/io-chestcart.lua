package.path = package.path .. ";/lib/?.lua"

local Side = require "elements.side"
local Peripheral = require "world.peripheral"
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

local function dumpChestcartToBarrel()
    while suck() do
    end

    if not dump(Side.bottom) then
        -- [todo] recover from this error.
        error("buffer barrel full")
    end

    if suck() then
        dumpChestcartToBarrel()
    end
end

local function dumpBarrelToChestcart()
    while suck(Side.bottom) do
    end

    if not dump(Side.front) then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived
        error("chestcart full")
    end

    if suck(Side.bottom) then
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
    if args[1] == "send-output" then
        sendOutput = true
    elseif args[1] == "send-input" then
        sendOutput = false
    else
        printUsage()
        return false
    end

    while true do
        local front = inspect(Side.front)

        if front and front.name == "minecraft:redstone_block" then
            local signal = Redstone.getInput({Side.left, Side.right})
            if signal then
                turn(signal)
            end
        elseif front and front.name == "minecraft:detector_rail" then
            if not Redstone.getInput(Side.front) then
                print("looking at rail, but no chestcart here. turning towards piston")
                local chest = Chest.findSide()
                turn(Side.rotateAround(chest))
            else
                dumpChestcartToBarrel()
                local chest = Chest.findSide()
                turn(chest)
            end
        elseif front and front.name == "minecraft:chest" then
            print("doing I/O...")
            local buffer = Peripheral.findSide("minecraft:barrel")
            local io = Chest.findSide()

            -- [todo] need to somehow support 27+ slot chests
            if sendOutput then
                pushInput(buffer, io)
                pullOutput(io, buffer, Chest.getInputOutputMaxStock(io))
            else
                pushOutput(buffer, io)
                pullInput(io, buffer)
            end

            local signal = Redstone.getInput({Side.left, Side.right})
            turn(signal)
            print("dumping barrel to chestcart...")
            dumpBarrelToChestcart()
            print("unlocking piston...")
            turn(signal)
            dig()
            os.sleep(3)
        elseif not front and Chest.findSide() == Side.back then
            os.sleep(3)
            if not Inventory.selectItem("minecraft:redstone_block") then
                error("my redstone block went missing :(")
            end

            print("waiting for chestcart...")
            os.pullEvent("redstone")

            local signal = Redstone.getInput({Side.left, Side.right})

            print("signal:", signal)

            print("locking piston...")
            if not place() then
                error("could not place redstone block to lock piston")
            end

            turn(signal)
        end

    end
end

return main(arg)
