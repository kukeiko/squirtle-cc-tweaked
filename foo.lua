local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Chest = require "world.chest"
local findSide = require "world.peripheral.find-side"
local pushOutput = require "squirtle.transfer.push-output"
local concatTables = require "utils.concat-tables"
local toIoInventory = require "inventory.to-io-inventory"
local EventLoop = require "event-loop"
local Rpc = require "rpc"
local Database = require "database"
local SubwayService = require "services.subway-service"

-- local value = table.pack(client.getTracks())
-- Utils.prettyPrint(value)

local client = Rpc.client(SubwayService, "bar")
local tracks = Database.getSubwayTracks("bar")
local track = tracks[math.random(#tracks)]

EventLoop.run(function()
    while true do
        local timerId = os.startTimer(2)

        EventLoop.pull("timer", function(_, id)
            if id ~= timerId then
                return
            end

            local readyToDispatch = client.readyToDispatchToTrack(track.signal)

            if readyToDispatch then
                track = tracks[math.random(#tracks)]
                print("switching to track", track.signal)
                client.dispatchToTrack(track.signal)
            else
                print("station busy")
            end
        end)
    end
end)

