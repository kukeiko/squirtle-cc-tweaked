package.path = package.path .. ";/?.lua"

local KiwiChest = require "kiwi.core.chest"
local KiwiPeripheral = require "kiwi.core.peripheral"
local KiwiSide = require "kiwi.core.side"
local KiwiUtils = require "kiwi.utils"
local takeInputAndPushOutput = require "kiwi.inventory.take-input-and-push-output"
local inspect = require "kiwi.turtle.inspect"
local turn = require "kiwi.turtle.turn"
local suck = require "kiwi.turtle.suck"
local Inventory = require "kiwi.turtle.inventory"
local drop = require "kiwi.turtle.drop"

local function facePistonPedestal()
    local chestSide = KiwiPeripheral.findSide("minecraft:chest")

    if chestSide == KiwiSide.left then
        turn(KiwiSide.right)
    elseif chestSide == KiwiSide.right then
        turn(KiwiSide.left)
    elseif chestSide == KiwiSide.front then
        turn(KiwiSide.back)
    end
end

local function dumpInventoryToBarrel()
    -- [todo] list() might return an array with all slots set in the future
    for slot in pairs(Inventory.list()) do
        Inventory.selectSlot(slot)
        -- [todo] hardcoded side & using native directly
        turtle.dropDown()
    end
end

local function main(args)
    -- redstone.setOutput(KiwiSide.front, true)
    facePistonPedestal()

    while true do
        os.pullEvent("redstone")

        local signalSide

        if redstone.getInput(KiwiSide.getName(KiwiSide.left)) then
            signalSide = KiwiSide.left
        elseif redstone.getInput(KiwiSide.getName(KiwiSide.right)) then
            signalSide = KiwiSide.right
        end

        if signalSide then
            local pistonSignalSide = KiwiSide.rotateAround(signalSide)
            redstone.setOutput(KiwiSide.getName(pistonSignalSide), true)
            turn(signalSide)

            while suck() do
            end

            if not Inventory.isEmpty() then
                dumpInventoryToBarrel()
            end

            if not Inventory.isEmpty() then
                error("buffer full")
            end

            while suck() do
            end

            if not Inventory.isEmpty() then
                dumpInventoryToBarrel()
            end

            if not Inventory.isEmpty() then
                error("buffer full")
            end

            redstone.setOutput(KiwiSide.getName(KiwiSide.back), true)
            turn(signalSide) -- turning to chest
            -------------------
            local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
            local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
            takeInputAndPushOutput(bufferBarrel, ioChest)
            -------------------
            turn(pistonSignalSide)
            redstone.setOutput(KiwiSide.getName(KiwiSide.back), false)
            while suck(KiwiSide.bottom) do
            end

            if not Inventory.isEmpty() then
                for slot in pairs(Inventory.list()) do
                    Inventory.selectSlot(slot)
                    drop()
                end
            end

            while suck(KiwiSide.bottom) do
            end

            if not Inventory.isEmpty() then
                for slot in pairs(Inventory.list()) do
                    Inventory.selectSlot(slot)
                    drop()
                end
            end

            turn(pistonSignalSide)
            redstone.setOutput(KiwiSide.getName(pistonSignalSide), false)
            os.sleep(1)
        else
            -- ignore, and maybe print warning?
        end

    end

end

return main(arg)
