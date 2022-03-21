package.path = package.path .. ";/lib/?.lua"

local Side = require "elements.side"
local Peripheral = require "world.peripheral"
local Chest = require "world.chest"
local Inventory = require "squirtle.inventory"
local pushInput = require "squirtle.transfer.push-input"
local takeOutput = require "squirtle.transfer.take-output"
local takeInputAndPushOutput = require "squirtle.transfer.take-input-and-push-output"
local turn = require "squirtle.turn"
local suck = require "squirtle.suck"
local drop = require "squirtle.drop"
local dump = require "squirtle.dump"

local function facePistonPedestal()
    local chestSide = Peripheral.findSide("minecraft:chest")

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

---@param chest Chest
---@return table<string, integer>
local function getMaxStock(chest)
    -- figure out how much stuff we can load up in total, which is summing input + output stacks in io-chest
    ---@type table<string, integer>
    local maxStock = {}

    for _, sourceItem in pairs(chest:getDetailedItemList()) do
        maxStock[sourceItem.name] = (maxStock[sourceItem.name] or 0) + sourceItem.maxCount
    end

    return maxStock
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
            local ioChest = Chest.new(Peripheral.findSide("minecraft:chest"))

            if sendOutput then
                pushInput(bufferBarrel, ioChest)
                local maxStock = getMaxStock(ioChest)
                takeOutput(ioChest, bufferBarrel, maxStock)
            else
                takeInputAndPushOutput(bufferBarrel, ioChest)
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
