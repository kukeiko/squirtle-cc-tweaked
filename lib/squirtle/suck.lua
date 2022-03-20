local KiwiSide = require "kiwi.core.side"
local natives = {[KiwiSide.top] = turtle.suckUp, [KiwiSide.front] = turtle.suck, [KiwiSide.bottom] = turtle.suckDown}

---@param side? integer|string
---@param limit? integer
---@return boolean,string?
return function(side, limit)
    local handler = natives[KiwiSide.fromArg(side or KiwiSide.front)]

    if not handler then
        error(string.format("suck() does not support side %s", KiwiSide.getName(side)))
    end

    return handler(limit)
end
