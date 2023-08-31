local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local locate = require "squirtle.locate"
local move = require "squirtle.move"
local face = require "squirtle.face"

---@param target Vector
---@return boolean, string?
return function(target)
    local delta = Vector.minus(target, locate())

    if delta.y > 0 then
        if not move("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not move("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        face(Cardinal.east)
        if not move("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        face(Cardinal.west)
        if not move("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        face(Cardinal.south)
        if not move("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        face(Cardinal.north)
        if not move("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end
