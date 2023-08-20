package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local navigate = require "squirtle.navigate"
local locate = require "squirtle.locate"
local orientate = require "squirtle.orientate"
local SquirtleV2 = require "squirtle.squirtle-v2"

local function main(args)
    print("[print3d v1.1.0]")
    local filename = args[1] or "whale_mini.t3d"
    local block = args[2] or "minecraft:stone_bricks"
    local file = fs.open(filename, "r")
    local pointsCompact = textutils.unserializeJSON(file.readAll())
    file.close()

    local _, facing = orientate()

    local points = Utils.map(pointsCompact, function(point)
        local point = Vector.create(point[1], point[2], point[3])

        if facing == Cardinal.east then
            point = Vector.rotateClockwise(point, 1)
        elseif facing == Cardinal.south then
            point = Vector.rotateClockwise(point, 2)
        elseif facing == Cardinal.west then
            point = Vector.rotateClockwise(point, 3)
        end

        return point
    end)

    local start = locate()

    for _, point in pairs(points) do
        local above = Vector.plus(point, Vector.create(0, 1, 0))
        local worldPoint = Vector.plus(start, above)
        local success, message = navigate(worldPoint)

        if not success then
            error(message)
        end

        SquirtleV2.placeDown(block)
    end
end

return main(arg)
