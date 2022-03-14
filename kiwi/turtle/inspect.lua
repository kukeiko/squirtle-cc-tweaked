local Side = require "kiwi.core.side"
local native = turtle

local natives = {
    [Side.top] = native.inspectUp,
    [Side.front] = native.inspect,
    [Side.bottom] = native.inspectDown
}

---@param side? integer|string
---@return KiwiBlock? block
return function(side)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("inspect() does not support side %s", Side.getName(side)))
    end

    local success, block = handler()

    if success then
        return block
    else
        return nil
    end
end
