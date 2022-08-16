local AppState = require "app-state"
local orientate = require "squirtle.orientate"
local setup = require "digger.setup"

return function()
    orientate()

    ---@type DiggerAppState
    local state = AppState.load("digger", {})

    if not state.home then
        state = setup()
        print("saving app state")
        AppState.save(state, "digger")
    end

    return AppState.load("digger", {})
end
