local Cardinal = require "kiwi.core.cardinal"
local Side = require "kiwi.core.side"
local locate = require "kiwi.turtle.locate"
local move = require "kiwi.turtle.move"
local face = require "kiwi.turtle.face"
local Utils = require "kiwi.utils"

---@param target KiwiVector
---@param options KiwiMoveOptions
return function(target, options)
    local l = locate()
    local delta = target:minus(locate())

    -- print("[move-to-locate]")
    -- Utils.prettyPrint(l)
    -- print("[move-to-delta]")
    -- Utils.prettyPrint(delta)
    -- Utils.waitForUserToHitEnter()
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
