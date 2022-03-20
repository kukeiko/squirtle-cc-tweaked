local Vector = require "lib.elements.vector"
local getState = require "lib.squirtle.get-state"
local changeState = require "lib.squirtle.change-state"

---@param refresh boolean
return function(refresh)
    local state = getState()
    local position = state.position

    if refresh or not position then
        local x, y, z = gps.locate()

        if not x then
            error({code = 0, message = "no gps available"})
        end

        position = Vector.new(x, y, z)
        changeState({position = position})
    end

    return position
end
