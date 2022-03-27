package.path = package.path .. ";/lib/?.lua"

local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Chest = require "world.chest"
local Redstone = require "world.redstone"
local pushInput = require "squirtle.transfer.push-input"
local pullOutput = require "squirtle.transfer.pull-output"
local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local turn = require "squirtle.turn"
local suck = require "squirtle.suck"
local dump = require "squirtle.dump"

local function facePistonPedestal()
    local chestSide = Chest.findSide()

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

        local signal

        if Redstone.getInput(Side.left) then
            signal = Side.left
        elseif Redstone.getInput(Side.right) then
            signal = Side.right
        end

        if signal then
            -- side we need to turn to to face piston after turning towards the signal
            local piston = Side.rotateAround(signal)
            Redstone.setOutput(piston, true)
            turn(signal)
            dumpChestcartToBarrel()
            Redstone.setOutput(Side.back, true)
            turn(signal) -- turning to chest

            local buffer = Peripheral.findSide("minecraft:barrel")
            local io = Chest.findSide()

            if sendOutput then
                pushInput(buffer, io)
                pullOutput(io, buffer, Chest.getInputOutputMaxStock(io))
            else
                pushOutput(buffer, io)
                pullInput(io, buffer)
            end

            turn(piston)
            Redstone.setOutput(Side.back, false)
            dumpBarrelToChest()
            turn(piston)
            Redstone.setOutput(piston, false)
            os.sleep(1)
        else
            -- ignore, and maybe print warning?
        end

    end

    return true
end

return main(arg)
