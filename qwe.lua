package.path = package.path .. ";/libs/?.lua"

local Inventory = require "inventory"
local Pretty = require "cc.pretty"
local Resources = require "resources"
local ResourceProviders = require "resource-providers"
local Utils = require "utils"

function testA()
    local requiredResources = {
        fuelLevel = 2,
        inventorySlot = 8,
        consumeItem = {
            {name = "minecraft:stick", count = 3},
            {name = "minecraft:diamond", count = 1}
        }
    }

    local providedResources = {
        consumeItem = {
            {name = "minecraft:diamond", count = 1},
            {name = "minecraft:stick", count = 2}
        },
        inventorySlot = 8
    }

    -- [todo] confusing because from reading this it looks like Resources.reduce()
    -- does not manipulate the table in place
    local reduced = Resources.reduce(requiredResources, providedResources)

    Pretty.print(Pretty.pretty(requiredResources))
end

function testB()
    local resourceProviders = ResourceProviders.new()

    -- print(turtle.getFuelLevel())

    -- local requiredResources = {fuelLevel = turtle.getFuelLevel() + 3}
    local requiredResources = {consumeItem = {{name = "minecraft:bamboo", count = 2}}}
    local expanded = resourceProviders:expand(requiredResources)

    if expanded then
        Utils.prettyPrint(expanded)
    end
end

function testC()
    print(Inventory.sumFuelLevel())
end

-- testA()
testB()
