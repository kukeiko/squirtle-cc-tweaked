package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local Vector = require "elements.vector"
local navigate = require "squirtle.navigate"
local locate = require "squirtle.locate"
local SquirtleV2 = require "squirtle.squirtle-v2"

local function main(args)
    print("[print3d v1.0.0]")
    local filename = args[1]
    local block = args[2]
    local file = fs.open(filename, "r")
    local pointsCompact = textutils.unserializeJSON(file.readAll())
    file.close()

    local points = Utils.map(pointsCompact, function(point)
        return Vector.create(point[1], point[2], point[3])
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
