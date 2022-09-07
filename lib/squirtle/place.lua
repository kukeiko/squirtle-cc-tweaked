local natives = {
    top = turtle.placeUp,
    up = turtle.placeUp,
    front = turtle.place,
    forward = turtle.place,
    bottom = turtle.placeDown,
    down = turtle.placeDown
}

---@param side? string
return function(side)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("place() does not support side %s", side))
    end

    return handler()
end
