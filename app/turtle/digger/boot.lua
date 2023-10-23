local AppState = require "app-state"
local Squirtle = require "squirtle"
local setup = require "digger.setup"

return function()
    Squirtle.orientate(true)

    ---@type DiggerAppState
    local state = AppState.load("digger", {})

    if not state.home then
        state = setup()
        print("saving app state")
        AppState.save(state, "digger")
    end

    return AppState.load("digger", {})
end
