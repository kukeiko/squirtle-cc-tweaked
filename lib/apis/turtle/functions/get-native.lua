-- pocket requires TurtleService, which requires full Squirtle code.
-- as a workaround, use empty table to prevent error on startup
local turtle = turtle or {}

local natives = {
    turn = {left = turtle.turnLeft, right = turtle.turnRight},
    go = {
        top = turtle.up,
        up = turtle.up,
        front = turtle.forward,
        forward = turtle.forward,
        bottom = turtle.down,
        down = turtle.down,
        back = turtle.back
    },
    dig = {top = turtle.digUp, up = turtle.digUp, front = turtle.dig, forward = turtle.dig, bottom = turtle.digDown, down = turtle.digDown},
    inspect = {
        top = turtle.inspectUp,
        up = turtle.inspectUp,
        front = turtle.inspect,
        forward = turtle.inspect,
        bottom = turtle.inspectDown,
        down = turtle.inspectDown
    },
    suck = {
        top = turtle.suckUp,
        up = turtle.suckUp,
        front = turtle.suck,
        forward = turtle.suck,
        bottom = turtle.suckDown,
        down = turtle.suckDown
    },
    place = {
        top = turtle.placeUp,
        up = turtle.placeUp,
        front = turtle.place,
        forward = turtle.place,
        bottom = turtle.placeDown,
        down = turtle.placeDown
    },
    drop = {
        top = turtle.dropUp,
        up = turtle.dropUp,
        front = turtle.drop,
        forward = turtle.drop,
        bottom = turtle.dropDown,
        down = turtle.dropDown
    }
}

---@param method string
---@param direction string
---@return function
return function(method, direction)
    local native = (natives[method] or {})[direction]

    if not native then
        error(string.format("%s does not support direction %s", method, direction))
    end

    return native
end
