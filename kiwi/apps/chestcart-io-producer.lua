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
local KiwiUtils = require "kiwi.utils"

---@param source KiwiChest
---@param target KiwiChest
function topOffInputStacks(source, target)
    local sourceItems = source:getDetailedItemList()
    local targetItems = target:getDetailedItemList()

    -- [todo] hardcoded input slot range
    for targetSlot = 1, 9 do
        local targetItem = targetItems[targetSlot]

        if targetItem ~= nil and targetItem:numMissing() > 0 then
            local numMissing = targetItem:numMissing()

            for sourceSlot, sourceItem in pairs(sourceItems) do
                -- checking for > 0 as we mutate it in place instead of removing entry
                -- from table as im not sure if that would work bug-free
                if sourceItem.count > 0 and sourceItem:equals(targetItem) then
                    local numToTransfer = math.min(sourceItem.count, numMissing)
                    local numTransferred = source:pushItems(target.side, sourceSlot, numToTransfer, targetSlot)
                    sourceItem.count = sourceItem.count - numTransferred
                    numMissing = numMissing - numTransferred
                end

                if numMissing <= 0 then
                    break
                end
            end
        end
    end
end

---@param source KiwiChest
---@param target KiwiChest
function takeOutput(source, target)
    -- figure out how much stuff we can load up in total,
    -- which is summing input + putput stacks in io-chest,
    -- then having a looky at how much we have in buffer,
    -- and only take what is needed to not exceed
    local sourceItems = source:getDetailedItemList()

    ---@type table<string, integer>
    local maxStock = {}

    for _, sourceItem in pairs(sourceItems) do
        maxStock[sourceItem.name] = (maxStock[sourceItem.name] or 0) + sourceItem.maxCount
    end

    KiwiUtils.prettyPrint(maxStock)

    local targetItems = target:getDetailedItemList()

    for _, targetItem in pairs(targetItems) do
        if maxStock[targetItem.name] ~= nil then
            maxStock[targetItem.name] = maxStock[targetItem.name] - targetItem.count
        end
    end

    -- [todo] hardcoded output slot range
    for slot = 10, 27 do
        local sourceItem = sourceItems[slot]

        if sourceItem ~= nil then
            local maxStockForItem = maxStock[sourceItem.name]

            if maxStockForItem ~= nil and maxStockForItem > 0 then
                local numToTransfer = math.min(sourceItem.count - 1, maxStockForItem)
                local numTransferred = source:pushItems(target.side, slot, numToTransfer)
                maxStock[sourceItem.name] = maxStockForItem - numTransferred
            end
        end
    end
end

function main(args)
    local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
    local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    topOffInputStacks(bufferBarrel, ioChest)
    takeOutput(ioChest, bufferBarrel)
end

return main(arg)
