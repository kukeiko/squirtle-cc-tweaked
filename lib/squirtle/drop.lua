local Side = require "elements.side"
local natives = {[Side.top] = turtle.dropUp, [Side.front] = turtle.drop, [Side.bottom] = turtle.dropDown}

---@param side? integer|string
---@param limit? integer
---@return boolean,string?
return function(side, limit)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("drop() does not support side %s", Side.getName(side)))
    end

    return handler(limit)
end
