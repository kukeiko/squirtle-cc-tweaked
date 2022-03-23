local Cardinal = require "elements.cardinal"
local Side = require "elements.side"
local locate = require "squirtle.locate"
local move = require "squirtle.move"
local face = require "squirtle.face"

---@param target Vector
---@param options SquirtleMoveOptions
return function(target, options)
    local delta = target:minus(locate())

    if delta.y > 0 then
        if not move(Side.top, delta.y, options) then
            return false, Side.top
        end
    elseif delta.y < 0 then
        if not move(Side.bottom, -delta.y, options) then
            return false, Side.bottom
        end
    end

    if delta.x > 0 then
        face(Cardinal.east)
        if not move(Side.front, delta.x, options) then
            return false, Side.front
        end
    elseif delta.x < 0 then
        face(Cardinal.west)
        if not move(Side.front, -delta.x, options) then
            return false, Side.front
        end
    end

    if delta.z > 0 then
        face(Cardinal.south)
        if not move(Side.front, delta.z, options) then
            return false, Side.front
        end
    elseif delta.z < 0 then
        face(Cardinal.north)
        if not move(Side.front, -delta.z, options) then
            return false, Side.front
        end
    end

    return true
end
