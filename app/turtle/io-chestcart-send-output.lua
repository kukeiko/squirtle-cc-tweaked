-- program for the turtle that is stationarily sitting on a barrel,
-- has a chestcart connected that is stopped via a piston,
-- and an io-chest next to it.
-- has an app arg to determine if the turtle should take output & supply input from the io-chest,
-- or if it should supply output & take input from the io-chest
-- each chestchart-io setup requires two such turtles with same block layout
-- or, alternatively, we could make two separate programs
package.path = package.path .. ";/?.lua"

local KiwiPeripheral = require "kiwi.core.peripheral"
local KiwiChest = require "kiwi.core.chest"
local pushInput = require "kiwi.inventory.push-input"
local takeOutput = require "kiwi.inventory.take-output"
local turn = require "kiwi.turtle.turn"
local suck = require "kiwi.turtle.suck"
local Inventory = require "kiwi.turtle.inventory"
local drop = require "kiwi.turtle.drop"
local KiwiSide = require "kiwi.core.side"

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

---@param chest KiwiChest
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
            pushInput(bufferBarrel, ioChest)
            local maxStock = getMaxStock(ioChest)
            takeOutput(ioChest, bufferBarrel, maxStock)
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

-- function main(args)
--     facePistonPedestal()

--     local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
--     local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
--     pushInput(bufferBarrel, ioChest)
--     local maxStock = getMaxStock(ioChest)
--     takeOutput(ioChest, bufferBarrel, maxStock)
-- end

return main(arg)
