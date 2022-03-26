package.path = package.path .. ";/lib/?.lua"

local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Chest = require "world.chest"
local pushInput = require "squirtle.transfer.push-input"
local takeOutput = require "squirtle.transfer.take-output"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local turn = require "squirtle.turn"
local suck = require "squirtle.suck"
local dump = require "squirtle.dump"

local function facePistonPedestal()
    local chestSide = Peripheral.findSide("minecraft:trapped_chest")

    if chestSide == Side.left then
        turn(Side.right)
    elseif chestSide == Side.right then
        turn(Side.left)
    elseif chestSide == Side.front then
        turn(Side.back)
    end
end

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

local function dumpBarrelToChest()
    while suck(Side.bottom) do
    end

    if not dump(Side.front) then
        -- [todo] recover from error. this should only happen when buffer already had items in it
        -- before chestcart arrived 
        error("chestcart full")
    end

    if suck(Side.bottom) then
        dumpBarrelToChest()
    end
end

local function printUsage()
    print("Usage:")
    print("io-chestcart send-output|send-input")
end

---@param args table
---@return boolean success
local function main(args)
    local sendOutput

    if args[1] == "send-output" then
        sendOutput = true
    elseif args[1] == "send-input" then
        sendOutput = false
    else
        printUsage()
        return false
    end

    facePistonPedestal()

    while true do
        os.pullEvent("redstone")

        local signalSide

        if redstone.getInput(Side.getName(Side.left)) then
            signalSide = Side.left
        elseif redstone.getInput(Side.getName(Side.right)) then
            signalSide = Side.right
        end

        if signalSide then
            local pistonSignalSide = Side.rotateAround(signalSide)
            redstone.setOutput(Side.getName(pistonSignalSide), true)
            turn(signalSide)
            dumpChestcartToBarrel()
            redstone.setOutput(Side.getName(Side.back), true)
            turn(signalSide) -- turning to chest

            local bufferBarrel = Chest.new(Peripheral.findSide("minecraft:barrel"))
            local ioChest = Chest.new(Peripheral.findSide("minecraft:trapped_chest"))

            if sendOutput then
                pushInput(bufferBarrel.side, ioChest.side)
                takeOutput(ioChest.side, bufferBarrel.side, Chest.getInputOutputMaxStock(ioChest.side))
            else
                pullInput(ioChest.side, bufferBarrel.side)
                pushOutput(bufferBarrel.side, ioChest.side, Chest.getInputMaxStock(ioChest.side))
            end

            turn(pistonSignalSide)
            redstone.setOutput(Side.getName(Side.back), false)
            dumpBarrelToChest()
            turn(pistonSignalSide)
            redstone.setOutput(Side.getName(pistonSignalSide), false)
            os.sleep(1)
        else
            -- ignore, and maybe print warning?
        end

    end

    return true
end

return main(arg)
