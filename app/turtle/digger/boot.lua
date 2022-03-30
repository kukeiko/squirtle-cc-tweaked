local Utils = require "utils"
local orientate = require "squirtle.orientate"
local setup = require "digger.setup"

return function()
    orientate()

    ---@type DiggerAppState
    local state = Utils.loadAppState("digger", {})

    if not state.home then
        setup()
    end

    return Utils.loadAppState("digger", {})
end
