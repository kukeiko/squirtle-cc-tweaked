local natives = {top = turtle.digUp, front = turtle.dig, bottom = turtle.digDown}

---@param side? string
---@param toolSide? string
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
