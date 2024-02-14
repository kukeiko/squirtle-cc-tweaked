local ccPretty = "cc.pretty"
local Pretty = require(ccPretty)
package.path = package.path .. ";/lib/?.lua"

local Squirtle = require "squirtle"
local Utils = require "utils"

-- local furnace = Inventory.create("top")
-- print(Inventory.hasSpaceForItem(furnace, "minecraft:lava_bucket"))

-- Squirtle.move("forward")
-- Squirtle.navigate(pos)
-- print(Squirtle.suckSlot("bottom", 2))
-- print(Squirtle.select("minecraft:barrel"))

-- Squirtle.pullInput_v2(toIoInventory("front"), Inventory.create("bottom"))

-- for _ = 1, 100 do
--     turtle.getItemSpace(1)
-- end

-- Squirtle.face(Cardinal.north)
-- print(Squirtle.selectEmpty(tonumber(arg[1])))

-- Squirtle.setBreakable(function(block)
--     return true
-- end)
-- print(Squirtle.place("minecraft:hopper"))

-- local value = table.pack(client.getTracks())
-- Utils.prettyPrint(value)

-- AppsService.folder = "test-apps"
-- local client = Rpc.nearest(AppsService)
-- AppsService.setComputerApps(client.getComputerApps(true), true)

-- ---@type SubwayStation
-- local subwayStation = {id = "foo", name = "Foo Bahnhof", type = "hub"}
-- local editEntity = EditEntity.new()

-- ---@type SubwayStationType[]
-- local types = {"hub", "endpoint", "platform", "switch"}

-- editEntity:addField("string", "id", "Id")
-- editEntity:addField("string", "name", "Name")
-- editEntity:addField("string", "type", "Type", {values = types})

-- local result = editEntity:run(subwayStation)
-- Utils.prettyPrint(result)

local EventLoop = require "event-loop"
local Inventory = require "inventory"

-- Inventories.mount("top")

-- print("[push]")
-- local pushed, open = Squirtle.pushOutput("bottom", "front")
-- Utils.prettyPrint(pushed)
-- Utils.prettyPrint(open)

-- EventLoop.waitForAny(function()
--     Inventory.start()
-- end, function()
--     os.sleep(1)
--     -- local itemStock = Inventories.getStockByTag("front", "input")
--     -- Utils.prettyPrint(itemStock)
--     print("[push]")
--     local pushed, open = Squirtle.pushOutput("bottom", "front")
--     Utils.prettyPrint(pushed)
--     Utils.prettyPrint(open)
--     -- print("[pull]")
--     -- Squirtle.pullInput("front", "bottom", pushed)
-- end)

Utils.prettyPrint(Utils.concat({}, {"foo"}, {}, {"bar", "baz"}))
-- Utils.prettyPrint({table.unpack({}), table.unpack({"foo"})})
-- Utils.prettyPrint(Utils.slice({table.unpack({}), table.unpack({"foo"})}, 1, 7))
