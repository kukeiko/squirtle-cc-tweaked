local Side = require "elements.side"
local native = turtle

local natives = {[Side.top] = native.digUp, [Side.front] = native.dig, [Side.bottom] = native.digDown}

---@param side? string|integer
---@param toolSide? string
return function(side, toolSide)
    side = side or Side.front
    local handler = natives[Side.fromArg(side)]

    if not handler then
        error(string.format("dig() does not support side %s", Side.getName(side)))
    end

    local success = handler(toolSide)

    -- omitting message on purpose
    -- [todo] what is that purpose?
    return success
end
