local DatabaseService = require "lib.services.database-service"
local SquirtleState = require "lib.squirtle.state"
local SquirtleBasicApi = require "lib.squirtle.api-layers.squirtle-basic-api"

---@return string
return function()
    local diskState = DatabaseService.getSquirtleDiskState()
    diskState.shulkerSides = SquirtleState.shulkerSides
    DatabaseService.saveSquirtleDiskState(diskState)
    local placedSide = SquirtleBasicApi.tryReplaceAtOneOf(SquirtleState.shulkerSides, "minecraft:shulker_box")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.shulkerSides = {}
        diskState.cleanupSides[placedSide] = "minecraft:shulker_box"
        DatabaseService.saveSquirtleDiskState(diskState)
    end

    return placedSide
end
