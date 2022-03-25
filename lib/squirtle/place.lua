local Side = require "elements.side"
local native = turtle

local natives = {[Side.top] = native.placeUp, [Side.front] = native.place, [Side.bottom] = native.placeDown}

---@param side? integer
return function(side)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("place() does not support side %s", Side.getName(side)))
    end

    return handler()
end
