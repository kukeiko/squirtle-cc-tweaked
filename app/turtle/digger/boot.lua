local AppState = require "lib.common.app-state"
local Squirtle = require "lib.squirtle.squirtle-api"
local setup = require "digger.setup"

return function()
    Squirtle.locate()
    Squirtle.orientate()

    ---@type DiggerAppState
    local state = AppState.load("digger", {})

    if not state.home then
        state = setup()
        print("saving app state")
        AppState.save(state, "digger")
    end

    return AppState.load("digger", {})
end
