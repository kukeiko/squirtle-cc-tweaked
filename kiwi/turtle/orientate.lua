local Side = require "kiwi.core.side"
local Cardinal = require "kiwi.core.cardinal"
local getState = require "kiwi.core.get-state"
local changeState = require "kiwi.core.change-state"
local locate = require "kiwi.turtle.locate"
local refuel = require "kiwi.turtle.refuel"
local move = require "kiwi.turtle.move"
local turn = require "kiwi.turtle.turn"

---@param side integer
---@param position KiwiVector
local function stepOut(side, position)
    refuel(2)

    if not move(side) then
        return false
    end

    local now = locate(true)
    local cardinal = Cardinal.fromVector(now:minus(position))
    local facing = Cardinal.rotate(cardinal, side)

    changeState({facing = facing})

    while not move(Side.rotateAround(side)) do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position KiwiVector
local function orientateSameLayer(position)
    -- [todo] note to self: i purposely turn first cause it looks nicer. especially
    -- when it moves back, then forward again. looks like a little dance.
    -- what i wrote this note actually for: allow for different styles and randomization
    turn(Side.right)
    local success = stepOut(Side.back, position) or stepOut(Side.front, position)
    turn(Side.left)

    if not success then
        success = stepOut(Side.back, position) or stepOut(Side.front, position)
    end

    return success
end

---@param refresh boolean
---@return KiwiVector position, integer facing
return function(refresh)
    local state = getState()
    local position = locate(refresh)
    local facing = state.facing

    if refresh or not facing then
        if not orientateSameLayer(position) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return locate(), facing
end
