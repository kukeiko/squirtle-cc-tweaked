package.path = package.path .. ";/libs/?.lua"

local Utils = require "squirtle.libs.utils"
local Kiwi = require "kiwi"
local World = require "kiwi.core.world"
local Body = require "kiwi.core.body"
local move = require "kiwi.turtle.move"
local orientate = require "kiwi.turtle.orientate"
local getState = require "kiwi.core.get-state"
local face = require "kiwi.turtle.face"
local navigate = require "kiwi.turtle.navigate"
local locate = require "kiwi.core.locate"
local isHome = require "kiwi.turtle.is-home"

function kiwiTest()
    print("is home:", isHome())
    local x = tonumber(arg[1])
    local y = tonumber(arg[2])
    local z = tonumber(arg[3])
    local start = locate()
    -- Utils.prettyPrint(start)
    local target = Kiwi.Vector.new(x, y, z)

    navigate(target)
    -- navigate(start)
end

kiwiTest()

-- local Inventory = require "inventory"
-- local Pretty = require "cc.pretty"
-- local Resources = require "resources"
-- local ResourceProviders = require "resource-providers"
-- local Utils = require "utils"

-- function testA()
--     local requiredResources = {
--         fuelLevel = 2,
--         inventorySlot = 8,
--         consumeItem = {
--             {name = "minecraft:stick", count = 3},
--             {name = "minecraft:diamond", count = 1}
--         }
--     }

--     local providedResources = {
--         consumeItem = {
--             {name = "minecraft:diamond", count = 1},
--             {name = "minecraft:stick", count = 2}
--         },
--         inventorySlot = 8
--     }

--     -- [todo] confusing because from reading this it looks like Resources.reduce()
--     -- does not manipulate the table in place
--     local reduced = Resources.reduce(requiredResources, providedResources)

--     Pretty.print(Pretty.pretty(requiredResources))
-- end

-- function testB()
--     local resourceProviders = ResourceProviders.new()

--     -- print(turtle.getFuelLevel())

--     -- local requiredResources = {fuelLevel = turtle.getFuelLevel() + 3}
--     local requiredResources = {consumeItem = {{name = "minecraft:bamboo", count = 2}}}
--     local expanded = resourceProviders:expand(requiredResources)

--     if expanded then
--         Utils.prettyPrint(expanded)
--     end
-- end

-- function testC()
--     print(Inventory.sumFuelLevel())
-- end

-- -- testA()
-- testB()
