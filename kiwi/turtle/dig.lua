local Side = require "kiwi.core.side"
local native = turtle

local natives = {
    [Side.top] = native.digUp,
    [Side.front] = native.dig,
    [Side.bottom] = native.digDown
}

---@param side integer
---@param toolSide? string
return function(side, toolSide)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("dig() does not support side %s", Side.getName(side)))
    end

    local success = handler(toolSide)

    -- omitting message on purpose
    return success
end
