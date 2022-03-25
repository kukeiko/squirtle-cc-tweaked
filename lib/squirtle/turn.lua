local Side = require "elements.side"
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

---@param side? integer|string defaults to Side.left
return function(side)
    side = Side.fromArg(side or Side.left)

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
