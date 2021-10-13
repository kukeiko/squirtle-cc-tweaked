package.path = package.path .. ";/?.lua"

local Inventory = require "squirtle.libs.turtle.inventory"
local Utils = require "squirtle.libs.utils"
local Refueler = require "squirtle.libs.turtle.refueler"
local FuelItems = require "squirtle.libs.fuel-items"
local Cardinal = require "squirtle.libs.cardinal"
local Side = require "squirtle.libs.side"
local Vector = require "squirtle.libs.vector"
local FuelProvider = require "squirtle.libs.rednet.fuel-provider"
local MessagePump = require "squirtle.libs.message-pump"
local Turtle = require "squirtle.libs.turtle"
local Transform = require "squirtle.libs.geo.transform"
local World = require "squirtle.libs.geo.world"

local pump = MessagePump.new()

pump:on("key", function(a, b, c)
    print(a)
    Turtle.turnLeft()

end)

local pumpInitialFn = function()
    print("hello!")
end

-- pump:run(pumpInitialFn)

function worldTransformStuffTest()
    local transform = Transform.new()
    local worldWidth = 3
    -- local world = World.new(transform, worldWidth, 1, 1, {})
    local world = World.new(transform, 5, 1, 11)

    local vectors = {Vector.new(5, 1, 11), Vector.new(5, 1, 12)}

    for i = 1, #vectors do
        local vector = vectors[i]
        print(vector, world:isInBounds(vector))
    end
end

function turtleOrientateTest()
    local facing, position = Turtle.orientate()
    print(Cardinal.getName(facing), position)
end

-- worldTransformStuffTest()
turtleOrientateTest()
