local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local Side = require "elements.side"
local locate = require "squirtle.locate"
local move = require "squirtle.move"
local face = require "squirtle.face"

---@param target Vector
return function(target)
    local delta = Vector.minus(target, locate())

    if delta.y > 0 then
        if not move(Side.top, delta.y) then
            return false, Side.top
        end
    elseif delta.y < 0 then
        if not move(Side.bottom, -delta.y) then
            return false, Side.bottom
        end
    end

    if delta.x > 0 then
        face(Cardinal.east)
        if not move(Side.front, delta.x) then
            return false, Side.front
        end
    elseif delta.x < 0 then
        face(Cardinal.west)
        if not move(Side.front, -delta.x) then
            return false, Side.front
        end
    end

    if delta.z > 0 then
        face(Cardinal.south)
        if not move(Side.front, delta.z) then
            return false, Side.front
        end
    elseif delta.z < 0 then
        face(Cardinal.north)
        if not move(Side.front, -delta.z) then
            return false, Side.front
        end
    end

    return true
end
