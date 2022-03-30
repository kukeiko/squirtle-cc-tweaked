local Utils = require "utils"
local Vectors = require "elements.vector"
local setup = require "expose-ores.setup"
local Transform = require "scout.transform"
local World = require "scout.world"

local function loadAppState()
    ---@type ExposeOresAppState
    local state = Utils.loadAppState("expose-ores", {})

    if state.world then
        local worldTransform = Transform.new(Vectors.new(state.world.x, state.world.y, state.world.z))
        state.world = World.new(worldTransform, state.world.width, state.world.height, state.world.depth)
    end

    if state.checkpoint then
        state.checkpoint = Vectors.cast(state.checkpoint)
    end

    if state.home then
        state.home = Vectors.cast(state.home)
    end

    if state.start then
        state.start = Vectors.cast(state.start)
    end

    return state
end

return function()
    local state = loadAppState()

    if not state.home then
        setup()
    end

    return loadAppState()
end
