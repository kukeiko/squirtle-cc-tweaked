package.path = package.path .. ";/?.lua"

local KiwiChest = require "kiwi.core.chest"
local KiwiPeripheral = require "kiwi.core.peripheral"
local KiwiUtils = require "kiwi.utils"
local takeInputAndPushOutput = require "kiwi.inventory.take-input-and-push-output"

local function main(args)
    local bufferBarrel = KiwiChest.new(KiwiPeripheral.findSide("minecraft:barrel"))
    local ioChest = KiwiChest.new(KiwiPeripheral.findSide("minecraft:chest"))
    takeInputAndPushOutput(bufferBarrel, ioChest)
end

return main(arg)
