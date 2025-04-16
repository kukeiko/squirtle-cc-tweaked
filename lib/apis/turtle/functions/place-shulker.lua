local DatabaseApi = require "lib.apis.database.database-api"
local TurtleBuildingApi = require "lib.apis.turtle.turtle-building-api"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"

---@return string
return function()
    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.shulkerSides = TurtleStateApi.getShulkerSides()
    DatabaseApi.saveSquirtleDiskState(diskState)
    local placedSide = TurtleBuildingApi.tryReplaceAtOneOf(TurtleStateApi.getShulkerSides(), "minecraft:shulker_box")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.shulkerSides = {}
        diskState.cleanupSides[placedSide] = "minecraft:shulker_box"
        DatabaseApi.saveSquirtleDiskState(diskState)
    end

    return placedSide
end
