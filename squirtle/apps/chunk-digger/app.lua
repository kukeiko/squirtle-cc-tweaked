package.path = package.path .. ";/?.lua"

local Side = require "squirtle.libs.side"
local Vector = require "squirtle.libs.vector"
local Cardinal = require "squirtle.libs.cardinal"
local Turtle = require "squirtle.libs.turtle"

local vectors = {home = Vector.new(7, 0, 7)}

local function main(args)
    print("[chunk-digger @ 1.0.0]")
    print("orientating...")

    local originalLocation = Vector.new(gps.locate())
    local chunkIndex = originalLocation:asChunkIndex()

    print("chunk index", chunkIndex)

    Turtle.dig(Side.top)
    Turtle.dig()
    Turtle.dig(Side.bottom)

    local s, e = Turtle.dig(Side.bottom)

    if not s then
        print(e)
    end

    -- turtle.forward()
    -- local newLocation = Vector.new(gps.locate())
    -- local cardinalVector = newLocation:minus(originalLocation)
    -- turtle.turnLeft()
    -- turtle.turnLeft()
    -- turtle.forward()
    -- local cardinal = Cardinal.fromVector(cardinalVector)
    -- cardinal = Cardinal.rotateAround(cardinal)
    -- print(Cardinal.getName(cardinal))

    -- Turtle.turnToCardinal(cardinal, Cardinal.rotateLeft(Cardinal.rotateAround(cardinal)))
end

function home()
end

main(arg)
