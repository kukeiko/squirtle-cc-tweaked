local Side = require "kiwi.core.side"
local Cardinal = require "kiwi.core.cardinal"
local getState = require "kiwi.core.get-state"
local changeState = require "kiwi.core.change-state"
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

---@param side integer
return function(side)
    if side == Side.left then
        return turnLeft()
    elseif side == Side.right then
        return turnRight()
    elseif side == Side.back then
        return turnBack()
    else
        error(string.format("turn() does not support side %s", Side.getName(side)))
    end
end
