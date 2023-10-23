local AppState = require "app-state"
local SquirtleV2 = require "squirtle.squirtle-v2"
local setup = require "digger.setup"

return function()
    SquirtleV2.orientate(true)

    ---@type DiggerAppState
    local state = AppState.load("digger", {})

    if not state.home then
        state = setup()
        print("saving app state")
        AppState.save(state, "digger")
    end

    return AppState.load("digger", {})
end
