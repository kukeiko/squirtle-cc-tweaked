local natives = {
    top = turtle.dropUp,
    up = turtle.dropUp,
    front = turtle.drop,
    bottom = turtle.dropDown,
    down = turtle.dropDown
}

---@param side? string
---@param limit? integer
---@return boolean, string?
return function(side, limit)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("drop() does not support side %s", side))
    end

    return handler(limit)
end
