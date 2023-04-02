local Cardinal = require "elements.cardinal"
local getState = require "squirtle.get-state"
local changeState = require "squirtle.change-state"
local native = turtle

local function turnLeft()
    local state = getState()
    local success, message = native.turnLeft()

    if not success then
        return false, message
    end

    if state.facing then
        changeState({facing = Cardinal.rotateLeft(state.facing)})
    end

    return true
end

local function turnRight()
    local state = getState()
    local success, message = native.turnRight()

    if not success then
        return false, message
    end

    if state.facing then
        changeState({facing = Cardinal.rotateRight(state.facing)})
    end

    return true
end

local function turnBack()
    local turnFn = turnLeft

    if math.random() < .5 then
        turnFn = turnRight
    end

    local success, message = turnFn()

    if not success then
        return false, message
    end

    return turnFn()
end

---@param side? string defaults to "left"
return function(side)
    -- [todo] turning to the left by default is not a good idea,
    -- makes it harder to find bugs in case a bad side is given, e.g. "nil" 
    side = side or "left"

    if side == "left" then
        return turnLeft()
    elseif side == "right" then
        return turnRight()
    elseif side == "back" then
        return turnBack()
    elseif side == "front" then
        return true
    else
        error(string.format("turn() does not support side %s", side))
    end
end
