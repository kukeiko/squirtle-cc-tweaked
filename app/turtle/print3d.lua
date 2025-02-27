if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Vector = require "lib.models.vector"
local Cardinal = require "lib.models.cardinal"
local Squirtle = require "lib.squirtle.squirtle-api"
local Print3dService = require "lib.systems.builders.print3d-service"
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
---@field homeFacing integer
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

    if not fs.exists(filename) then
        error(string.format("file %s doesn't exist", filename))
    elseif fs.isDir(filename) then
        error(string.format("%s is a directory, not a file", filename))
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

    ---@type Vector
    local previousPoint = Vector.create(0, 0, 0);

    ---@type ColoredPoint[]
    local points = {}

    for i = 1, #blueprint.points, 4 do
        local deltaX = blueprint.points[i]
        local deltaY = blueprint.points[i + 1]
        local deltaZ = blueprint.points[i + 2]
        local block = blueprint.palette[blueprint.points[i + 3]]
        blocks[block] = (blocks[block] or 0) + 1

        local pointVector = Vector.create(previousPoint.x + deltaX, previousPoint.y + deltaY, previousPoint.z + deltaZ)
        ---@type ColoredPoint
        local point = {vector = pointVector, block = block}
        table.insert(points, point)
        previousPoint = Vector.copy(pointVector)
    end

    print(string.format("[found] %dx voxels", #points))
    os.sleep(1)

    ---@type ColoredPoint[]
    points = Utils.map(points, function(point)
        if facing == Cardinal.east then
            point.vector = Vector.rotateClockwise(point.vector, 1)
        elseif facing == Cardinal.south then
            point.vector = Vector.rotateClockwise(point.vector, 2)
        elseif facing == Cardinal.west then
            point.vector = Vector.rotateClockwise(point.vector, 3)
        end

        return point
    end)

    Squirtle.requireItems(blocks, true)

    print("[ok] all good! waiting for pda signal")

    while not Print3dService.isOn() do
        os.sleep(.5)
    end

    local offset = Vector.create(blueprint.x, 0, 0)

    if facing == Cardinal.east then
        offset = Vector.rotateClockwise(offset, 1)
    elseif facing == Cardinal.south then
        offset = Vector.rotateClockwise(offset, 2)
    elseif facing == Cardinal.west then
        offset = Vector.rotateClockwise(offset, 3)
    end

    ---@type Print3DState
    local state = {home = home, homeFacing = facing, points = points, offset = offset}

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

    Squirtle.face(state.homeFacing)
end

-- https://3dviewer.net/ for rotating
-- https://drububu.com/miscellaneous/voxelizer/?out=obj for voxelizing
print(string.format("[print3d %s]", version()))
os.sleep(1)

-- [todo] add kill-switch - turtle should return home
EventLoop.run(function()
    EventLoop.runUntil("print3d:stop", function()
        Rpc.host(SquirtleService)
    end)
end, function()
    EventLoop.runUntil("print3d:stop", function()
        Rpc.host(Print3dService)
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
