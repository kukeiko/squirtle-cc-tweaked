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

function main(args)
    local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
    local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    pushInput(bufferBarrel, ioChest)
    local maxStock = getMaxStock(ioChest)
    takeOutput(ioChest, bufferBarrel, maxStock)
end

return main(arg)
