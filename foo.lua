local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
-- local Side = require "elements.side"
local Chest = require "world.chest"
local findSide = require "world.peripheral.find-side"
-- local pullInput = require "squirtle.transfer.pull-input"
local pushOutput = require "squirtle.transfer.push-output"
local concatTables = require "utils.concat-tables"
local toIoInventory = require "inventory.to-io-inventory"
-- local inspect = require "squirtle.inspect"
-- local Backpack = require "squirtle.backpack"
-- local suckSlotFromChest = require "squirtle.transfer.suck-slot-from-chest"
-- local Redstone = require "world.redstone"
local EventLoop = require "event-loop"
local Rpc = require "rpc"
local SubwayService = require "subway.subway-service"
-- Redstone.setOutput(Side.front, true)

-- local value = pushOutput("bottom", "front", {["minecraft:ender_pearl"] = 2})
-- local value = {pushOutput("bottom", "front")}
-- local value = concatTables({1, 2, 3}, {"four", "five", "six"}, {7, 8, 9})
-- local value = toIoInventory("front", {})
-- for slot, stack in pairs(value) do
--     print(stack.maxCount)
-- end

local client = Rpc.client(SubwayService, "bar-station")
local tracks = client.getTracks()

for _, track in pairs(tracks) do
    print("switching to track", track.signal)
    client.dispatchToTrack(track.signal)
end

local value = table.pack(client.getTracks())
Utils.prettyPrint(value)
