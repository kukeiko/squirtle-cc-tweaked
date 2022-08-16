local indexOf = require "utils.index-of"
local Side = require "elements.side"
local native = turtle

local natives = {[Side.top] = native.inspectUp, [Side.front] = native.inspect, [Side.bottom] = native.inspectDown}

---@param side? integer|string
---@param name? table|string
---@return Block? block
return function(side, name)
    local handler = natives[Side.fromArg(side or Side.front)]

    if not handler then
        error(string.format("inspect() does not support side %s", Side.getName(side)))
    end

    local success, block = handler()

    if success then
        if name then
            if type(name) == "string" and block.name == name then
                return block
            elseif type(name) == "table" and indexOf(name, block.name) > 0 then
                return block
            else
                return nil
            end
        end

        return block
    else
        return nil
    end
end
