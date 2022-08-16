local Vector = require "elements.vector"
local getState = require "squirtle.get-state"
local changeState = require "squirtle.change-state"

---@param refresh? boolean
return function(refresh)
    local state = getState()
    local position = state.position

    if refresh or not position then
        local x, y, z = gps.locate()

        if not x then
            error("no gps available")
        end

        position = Vector.create(x, y, z)
        changeState({position = position})
    end

    return position
end
