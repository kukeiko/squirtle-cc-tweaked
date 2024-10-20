package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local SquirtleService = require "lib.squirtle.squirtle-service"
local Vector = require "lib.common.vector"
local Cardinal = require "lib.common.cardinal"
local Squirtle = require "lib.squirtle.squirtle-api"
local Print3dService = require "lib.features.print3d-service"
local SquirtleService = require "lib.squirtle.squirtle-service"

---@class ColoredPoint
---@field vector Vector
---@field block string?
---
---@class Blueprint3D
---@field x integer
---@field fuel integer
---@field palette string[]
---@field points [integer, integer, integer, integer][]
---
---@class Print3DState
---@field home Vector
---@field offset Vector
---@field points ColoredPoint[]
---

local function printUsage()
    print("Usage: print3d <file>")
end

---@param args string[]
---@return Print3DState?
local function start(args)
    local filename = args[1]

    if not filename then
        return printUsage()
    end

    local file = fs.open(filename, "r")
    ---@type Blueprint3D
    local blueprint = textutils.unserializeJSON(file.readAll())
    file.close()

    Squirtle.configure({shulkerSides = {"top"}})
    Squirtle.refuelTo(blueprint.fuel + 1000);
    local facing = Squirtle.orientate("disk-drive", {"top"})
    local home = Squirtle.locate()
    ---@type ItemStock
    local blocks = {}

    ---@type ColoredPoint[]
    local points = Utils.map(blueprint.points, function(point)
        local block = blueprint.palette[point[4]]
        local point = Vector.create(point[1], point[2], point[3])

        if facing == Cardinal.east then
            point = Vector.rotateClockwise(point, 1)
        elseif facing == Cardinal.south then
            point = Vector.rotateClockwise(point, 2)
        elseif facing == Cardinal.west then
            point = Vector.rotateClockwise(point, 3)
        end

        blocks[block] = (blocks[block] or 0) + 1

        return {vector = point, block = block}
    end)

    Squirtle.requireItems(blocks, true)

    print("[ok] all good! waiting for pda signal")

    while not Print3dService.isOn() do
        os.sleep(.5)
    end

    -- [todo] offset needs to be tested
    local offset = Vector.create(blueprint.x, 0, 0)

    if facing == Cardinal.east then
        offset = Vector.rotateClockwise(offset, 1)
    elseif facing == Cardinal.south then
        offset = Vector.rotateClockwise(offset, 2)
    elseif facing == Cardinal.west then
        offset = Vector.rotateClockwise(offset, 3)
    end

    ---@type Print3DState
    local state = {home = home, points = points, offset = offset}

    return state
end

---@param state Print3DState
local function main(state)
    for _, point in pairs(state.points) do
        while not Print3dService.isOn() do
            os.sleep(1)
        end

        local above = Vector.plus(point.vector, Vector.create(0, 1, 0))
        local worldPoint = Vector.minus(Vector.plus(state.home, above), state.offset)
        local success, message = Squirtle.navigate(worldPoint, nil, function()
            return true
        end)

        if not success then
            error(message)
        end

        Squirtle.put("bottom", point.block)
    end
end

local function resume()
    Squirtle.configure({shulkerSides = {"top"}})
    Squirtle.orientate("disk-drive", {"top"})
    Squirtle.locate()
end

---@param state Print3DState
local function finish(state)
    Squirtle.navigate(state.home, nil, function()
        return false
    end)
end

-- https://3dviewer.net/ for rotating
-- https://drububu.com/miscellaneous/voxelizer/?out=obj for voxelizing
print("[print3d v2.0.0-dev]")

-- [todo] add kill-switch - turtle should return home
-- app\turtle\print3d\print3d.lua 3d-blueprints\fat-tree\printing\
EventLoop.run(function()
    EventLoop.runUntil("print3d:stop", function()
        Rpc.server(SquirtleService)
    end)
end, function()
    EventLoop.runUntil("print3d:stop", function()
        Rpc.server(Print3dService)
    end)
end, function()
    local success, message = Squirtle.runResumable("print3d", arg, start, main, resume, finish)

    if success then
        EventLoop.queue("print3d:stop")
        print("[done] I hope you like what I built!")
    else
        print(message)
        SquirtleService.error = message
    end
end)
