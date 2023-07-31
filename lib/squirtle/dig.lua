local natives = {
    top = turtle.digUp,
    up = turtle.digUp,
    front = turtle.dig,
    forward = turtle.dig,
    bottom = turtle.digDown,
    down = turtle.digDown
}

---@param side? string
---@param toolSide? string
---@return boolean
return function(side, toolSide)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("dig() does not support side %s", side))
    end

    local success = handler(toolSide)

    -- omitting message on purpose
    -- [todo] what is that purpose?
    return success
end
