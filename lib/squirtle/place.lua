local Side = require "elements.side"
local native = turtle

local natives = {[Side.top] = native.placeUp, [Side.front] = native.place, [Side.bottom] = native.placeDown}

---@param side? string|integer
return function(side)
    side = side or Side.front
    local handler = natives[Side.fromArg(side)]

    if not handler then
        error(string.format("place() does not support side %s", Side.getName(side)))
    end

    return handler()
end
