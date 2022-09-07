local Vector = require "elements.vector"
local Side = require "elements.side"
local Cardinal = require "elements.cardinal"
local getState = require "squirtle.get-state"
local changeState = require "squirtle.change-state"
local locate = require "squirtle.locate"
local refuel = require "squirtle.refuel"
local move = require "squirtle.move"
local turn = require "squirtle.turn"

---@param side string
---@param position Vector
local function stepOut(side, position)
    refuel(2)

    if not move(side) then
        return false
    end

    local now = locate(true)
    local cardinal = Cardinal.fromVector(Vector.minus(now, position))
    local facing = Cardinal.rotate(cardinal, side)

    changeState({facing = facing})

    while not move(Side.rotateAround(side)) do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
local function orientateSameLayer(position)
    -- [todo] note to self: i purposely turn first cause it looks nicer. especially
    -- when it moves back, then forward again. looks like a little dance.
    -- what i wrote this note actually for: allow for different styles and randomization
    -- [todo#2] well, good i wrote this note. because i was surprised that the turtle
    -- doesn't first try simply moving forward, and i was wondering why.
    turn("right")
    local success = stepOut("back", position) or stepOut("front", position)
    turn("left")

    if not success then
        success = stepOut("back", position) or stepOut("front", position)
    end

    return success
end

---@param refresh? boolean
---@return Vector position, integer facing
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
