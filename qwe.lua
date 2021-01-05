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

    local reduced = Resources.reduce(requiredResources, providedResources)

    Pretty.print(Pretty.pretty(reduced))
end

function testB()
    local resourceProviders = ResourceProviders.new()
    local found = resourceProviders:find({fuelLevel = turtle.getFuelLevel() + 3})

    Utils.prettyPrint(found)

    for i = 1, #found do
        print("exec provider...")
        found[i].execute()
    end
end

function testC()
    print(Inventory.sumFuelLevel())
end

testB()
