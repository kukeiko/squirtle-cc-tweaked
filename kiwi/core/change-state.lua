local getState = require "kiwi.core.get-state"

---@param patch KiwiState
return function(patch)
    local state = getState()

    for key, value in pairs(patch) do
        state[key] = value
    end

    return state
end
