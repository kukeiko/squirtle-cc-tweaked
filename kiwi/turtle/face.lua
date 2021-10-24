local Side = require "kiwi.core.side"
local getState = require "kiwi.core.get-state"
local turn = require "kiwi.turtle.turn"

---@param target integer
---@param current? integer
return function(target, current)
    local state = getState()
    current = current or state.facing

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        turn(Side.back)
    elseif (current + 1) % 4 == target then
        turn(Side.right)
    elseif (current - 1) % 4 == target then
        turn(Side.left)
    end

    return target
end
