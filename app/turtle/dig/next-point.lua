local Vector = require "elements.vector"
local World = require "geo.world"

---@param world World
---@param start Vector
local function isStartInBottomPlane(world, start)
    if World.isInBottomPlane(world, start) then
        return true
    elseif World.isInTopPlane(world, start) then
        return false
    else
        error("start must be in either world bottom or top plane")
    end
end

---@param world World
---@param layerHeight integer
---@return integer
function getNumLayers(world, layerHeight)
    return math.ceil(world.height / layerHeight)
end

---@param point Vector
---@param world World
---@param start Vector
---@param layerHeight integer
---@return integer
function getCurrentLayer(point, world, start, layerHeight)
    if layerHeight >= world.height then
        return 1
    end

    if isStartInBottomPlane(world, start) then
        return math.floor((point.y - world.y) / layerHeight) + 1
    else
        return math.floor(((world.y + world.height - 1) - point.y) / layerHeight) + 1
    end
end

---@param layer integer
---@param world World
---@param start Vector
---@param layerHeight integer
---@return integer
function getLayerTargetY(layer, world, start, layerHeight)
    if isStartInBottomPlane(world, start) then
        local targetY = math.floor(layerHeight / 2) + ((layer - 1) * layerHeight) + world.y

        if not World.isInBoundsY(world, targetY) then
            return world.y + world.height - 1
        else
            return targetY
        end
    else
        local targetY = (world.y + world.height - 1) - math.floor(layerHeight / 2) + ((layer - 1) * layerHeight)

        if not World.isInBoundsY(world, targetY) then
            return world.y
        else
            return targetY
        end
    end
end

---@param point Vector
---@param world World
---@param start Vector
---@param layerHeight? integer
---@return Vector?
return function(point, world, start, layerHeight)
    layerHeight = layerHeight or 3

    -- first we try to move to the correct y position, based on which layer we are in
    local currentLayer = getCurrentLayer(point, world, start, layerHeight)
    local targetY = getLayerTargetY(currentLayer, world, start, layerHeight)

    if point.y ~= targetY then
        if isStartInBottomPlane(world, start) then
            return Vector.plus(point, Vector.create(0, 1, 0))
        else
            return Vector.plus(point, Vector.create(0, -1, 0))
        end
    end

    -- then we snake through the plane for digging
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

    if world.width > world.depth then
        local relative = Vector.minus(point, start)

        if relative.z % 2 == 1 then
            delta.x = delta.x * -1
        end

        if (currentLayer - 1) % 2 == 1 then
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

        if (currentLayer - 1) % 2 == 1 then
            delta.x = delta.x * -1
            delta.z = delta.z * -1
        end

        if World.isInBoundsZ(world, point.z + delta.z) then
            return Vector.plus(point, Vector.create(0, 0, delta.z))
        elseif World.isInBoundsX(world, point.x + delta.x) then
            return Vector.plus(point, Vector.create(delta.x, 0, 0))
        end
    end

    -- after that, advance to the next layer, or stop if we are at the max layer
    if currentLayer == getNumLayers(world, layerHeight) then
        return nil
    elseif isStartInBottomPlane(world, start) then
        if World.isInBoundsY(world, point.y + 1) then
            return Vector.plus(point, Vector.create(0, 1, 0))
        end
    else
        if World.isInBoundsY(world, point.y - 1) then
            return Vector.plus(point, Vector.create(0, -1, 0))
        end
    end
end
