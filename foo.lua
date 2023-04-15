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
local Database = require "services.database-service"
local AppsService = require "services.apps-service"
local SubwayService = require "services.subway-service"
local DatabaseService = require "services.database-service"

-- local value = table.pack(client.getTracks())
-- Utils.prettyPrint(value)

AppsService.folder = "test-apps"
local client = Rpc.nearest(AppsService)
AppsService.setComputerApps(client.getComputerApps(true), true)

