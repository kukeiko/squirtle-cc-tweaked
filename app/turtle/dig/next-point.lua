local Vector = require "elements.vector"
local World = require "geo.world"

---@param point Vector
---@param world World
---@param start Vector
return function(point, world, start)
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
