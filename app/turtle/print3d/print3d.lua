package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local navigate = require "squirtle.navigate"
local locate = require "squirtle.locate"
local orientate = require "squirtle.orientate"
local SquirtleV2 = require "squirtle.squirtle-v2"
local requireItems = require "squirtle.require-items"

---@class ColoredPoint
---@field vector Vector
---@field block string?

local function main(args)
    print("[print3d v1.3.0]")
    local filename = args[1] or "seahorse-colored_27.t3d"
    local defaultBlock = args[2] or "minecraft:stone_bricks"
    local file = fs.open(filename, "r")
    local pointsCompact = textutils.unserializeJSON(file.readAll())
    file.close()

    local _, facing = orientate()
    ---@type table<string, integer>
    local blocks = {}

    ---@type ColoredPoint[]
    local points = Utils.map(pointsCompact, function(point)
        local block = point[4]
        local point = Vector.create(point[1], point[2], point[3])

        if facing == Cardinal.east then
            point = Vector.rotateClockwise(point, 1)
        elseif facing == Cardinal.south then
            point = Vector.rotateClockwise(point, 2)
        elseif facing == Cardinal.west then
            point = Vector.rotateClockwise(point, 3)
        end

        local usedBlock = block or defaultBlock
        blocks[usedBlock] = (blocks[usedBlock] or 0) + 1

        -- [todo] dirty hack to make sure we can start. missing blocks will have to be added during printing

        if blocks[usedBlock] > 64 then
            blocks[usedBlock] = 64
        end

        return {vector = point, block = block}
    end)

    requireItems(blocks)
    local start = locate()

    for _, point in pairs(points) do
        local above = Vector.plus(point.vector, Vector.create(0, 1, 0))
        local worldPoint = Vector.plus(start, above)
        local success, message = navigate(worldPoint, nil, function()
            return true
        end)

        if not success then
            error(message)
        end

        SquirtleV2.placeDown(point.block or defaultBlock)
    end

    navigate(start)
    SquirtleV2.face(facing)
end

return main(arg)
