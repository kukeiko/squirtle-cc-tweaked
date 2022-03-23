local Side = require "elements.side"
local natives = {[Side.top] = turtle.suckUp, [Side.front] = turtle.suck, [Side.bottom] = turtle.suckDown}

---@param side? integer|string
---@param limit? integer
---@return boolean,string?
return function(side, limit)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("suck() does not support side %s", Side.getName(side)))
    end

    return handler(limit)
end
