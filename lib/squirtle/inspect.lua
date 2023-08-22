local indexOf = require "utils.index-of"

local natives = {
    top = turtle.inspectUp,
    up = turtle.inspectUp,
    front = turtle.inspect,
    forward = turtle.inspect,
    bottom = turtle.inspectDown,
    down = turtle.inspectDown
}

---@param side? string
---@param name? table|string
---@return Block? block
return function(side, name)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("inspect() does not support side %s", side))
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
