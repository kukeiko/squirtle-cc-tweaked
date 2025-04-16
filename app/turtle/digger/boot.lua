local AppState = require "lib.apis.app-state"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local setup = require "digger.setup"

return function()
    TurtleApi.locate()
    TurtleApi.orientate()

    ---@type DiggerAppState
    local state = AppState.load("digger", {})

    if not state.home then
        state = setup()
        print("saving app state")
        AppState.save(state, "digger")
    end

    return AppState.load("digger", {})
end
