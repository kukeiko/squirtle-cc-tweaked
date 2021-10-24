local getState = require "kiwi.core.get-state"
local isHome = require "kiwi.turtle.is-home"

return function()
    if isHome() then
        return
    end

    local state = getState()

    if not position or not state.facing then
        -- i think i was trying to check if gps is available, and if not, do... ? no idea
    end
end
