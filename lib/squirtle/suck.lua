local natives = {
    top = turtle.suckUp,
    up = turtle.suckUp,
    front = turtle.suck,
    forward = turtle.suck,
    bottom = turtle.suckDown,
    down = turtle.suckDown
}

---@param side? string
---@param limit? integer
---@return boolean,string?
return function(side, limit)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("suck() does not support side %s", side))
    end

    return handler(limit)
end
