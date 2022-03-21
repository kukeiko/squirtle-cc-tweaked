local getState = require "squirtle.get-state"

---@param patch SquirtleState
return function(patch)
    local state = getState()

    for key, value in pairs(patch) do
        state[key] = value
    end

    return state
end
