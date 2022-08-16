package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local changeState = require "squirtle.change-state"
local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local World = require "geo.world"
local navigate = require "squirtle.navigate"
local locate = require "squirtle.locate"
local dig = require "squirtle.dig"
local face = require "squirtle.face"
local Fuel = require "squirtle.fuel"

local function printUsage()
    print("Usage:")
    print("dig <depth> <width> <height>")
    print("(negative numbers possible)")
end

local function refuel(level)
    if Fuel.hasFuel(level) then
        return true
    end

    shell.run("refuel", "all")

    while not Fuel.hasFuel(level) do
        print(string.format("[help] not enough fuel, need %d more.", Fuel.getMissingFuel(level)))
        print("please put some into inventory")
        os.pullEvent("turtle_inventory")
        shell.run("refuel", "all")
    end
end

---@param point Vector
---@param world World
---@param start Vector
local function nextPoint(point, world, start)
    local delta = Vector.create(0, 0, 0)

    if start.x == world.x then
        delta.x = 1
    elseif start.x == world.x + world.width - 1 then
        delta.x = -1
    end

    if start.z == world.z then
        delta.z = 1
    elseif start.z == world.z + world.depth - 1 then
        delta.z = -1
    end

    if start.y == world.y then
        delta.y = 3
    elseif start.y == world.y + world.height - 1 then
        delta.y = -3
    end

    if world.width > world.depth then
        local relative = Vector.minus(point, start)

        if relative.z % 2 == 1 then
            delta.x = delta.x * -1
        end

        if relative.y % 2 == 1 then
            delta.x = delta.x * -1
            delta.z = delta.z * -1
        end

        if World.isInBoundsX(world, point.x + delta.x) then
            return Vector.plus(point, Vector.create(delta.x, 0, 0))
        elseif World.isInBoundsZ(world, point.z + delta.z) then
            return Vector.plus(point, Vector.create(0, 0, delta.z))
        end
    else
        local relative = Vector.minus(point, start)

        if relative.x % 2 == 1 then
            delta.z = delta.z * -1
        end

        if relative.y % 2 == 1 then
            delta.x = delta.x * -1
            delta.z = delta.z * -1
        end

        if World.isInBoundsZ(world, point.z + delta.z) then
            return Vector.plus(point, Vector.create(0, 0, delta.z))
        elseif World.isInBoundsX(world, point.x + delta.x) then
            return Vector.plus(point, Vector.create(delta.x, 0, 0))
        end
    end

    if World.isInBoundsY(world, point.y + delta.y) then
        return Vector.plus(point, Vector.create(0, delta.y, 0))
    else
        local unitY = delta.y / 3;

        if World.isInBoundsY(world, point.y + (2 * unitY)) then
            -- one more Y layer to dig, move one up. digUp() is the only thing that'll happen
            return Vector.plus(point, Vector.create(0, unitY, 0))
        else
            return nil
        end
    end

end

---@param world World
---@param position Vector
local function digUpDownIfInBounds(world, position)
    if World.isInBoundsY(world, position.y + 1) then
        dig("top")
    end

    if World.isInBoundsY(world, position.y - 1) then
        dig("bottom")
    end
end

local function isBreakable(block)
    if not block then
        return false
    end

    return true
end

---@param args table<string>
local function main(args)
    print("[dig v1.0.0] booting...")
    local depth = tonumber(args[1])
    local width = tonumber(args[2])
    local height = tonumber(args[3])

    if not depth or not width or not height or depth == 0 or width == 0 or height == 0 then
        return printUsage()
    end

    depth = -depth

    local returnTripFuel = math.abs(depth) + math.abs(width) + math.abs(height)
    local numBlocks = math.abs(depth) * math.abs(width) * math.abs(height)
    print(numBlocks .. "x blocks, guessing " .. numBlocks / 32 .. " stacks")

    local requiredFuel = math.ceil((numBlocks + returnTripFuel) * 1.2)
    refuel(requiredFuel)

    local position = Vector.create(0, 0, 0)
    local facing = Cardinal.north
    changeState({facing = facing, position = position})

    local worldX = 0
    local worldY = 0
    local worldZ = 0

    if width < 0 then
        worldX = position.x + width + 1
        width = math.abs(width)
    end

    if height < 0 then
        worldY = position.y + height + 1
        height = math.abs(height)
    end

    if depth < 0 then
        worldZ = position.z + depth + 1
        depth = math.abs(depth)
    end

    local world = World.create(worldX, worldY, worldZ, width, height, depth)

    ---@type Vector|nil
    local point = position
    local start = position

    while point do
        if navigate(point, world, isBreakable) then
            digUpDownIfInBounds(world, locate())
        end

        point = nextPoint(point, world, start)
    end

    print("all done! going home...")
    navigate(start, world, isBreakable)
    face(facing)
end

return main(arg)
