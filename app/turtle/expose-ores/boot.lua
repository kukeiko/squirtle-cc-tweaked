local Utils = require "utils"
local orientate = require "squirtle.orientate"
local setup = require "expose-ores.setup"

return function()
    orientate()

    ---@type ExposeOresAppState
    local state = Utils.loadAppState("expose-ores", {})

    if not state.home then
        setup()
    end

    return Utils.loadAppState("expose-ores", {})
end
