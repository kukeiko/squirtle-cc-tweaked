local DatabaseApi = require "lib.apis.database.database-api"
local SquirtleState = require "lib.squirtle.state"
local TurtleBuildingApi = require "lib.apis.turtle.turtle-building-api"

---@return string
return function()
    local diskState = DatabaseApi.getSquirtleDiskState()
    -- [todo] use TurtleStateApi
    diskState.shulkerSides = SquirtleState.shulkerSides
    DatabaseApi.saveSquirtleDiskState(diskState)
    local placedSide = TurtleBuildingApi.tryReplaceAtOneOf(SquirtleState.shulkerSides, "minecraft:shulker_box")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.shulkerSides = {}
        diskState.cleanupSides[placedSide] = "minecraft:shulker_box"
        DatabaseApi.saveSquirtleDiskState(diskState)
    end

    return placedSide
end
