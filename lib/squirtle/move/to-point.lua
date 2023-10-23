local Vector = require "elements.vector"
local Cardinal = require "elements.cardinal"
local SquirtleV2 = require "squirtle.squirtle-v2"

---@param target Vector
---@return boolean, string?
return function(target)
    local delta = Vector.minus(target, SquirtleV2.locate())

    if delta.y > 0 then
        if not SquirtleV2.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not SquirtleV2.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        SquirtleV2.face(Cardinal.east)
        if not SquirtleV2.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        SquirtleV2.face(Cardinal.west)
        if not SquirtleV2.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        SquirtleV2.face(Cardinal.south)
        if not SquirtleV2.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        SquirtleV2.face(Cardinal.north)
        if not SquirtleV2.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end
