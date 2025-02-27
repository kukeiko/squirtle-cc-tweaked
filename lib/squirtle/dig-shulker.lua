local DatabaseService = require "lib.services.database-service"
local SquirtleBasicApi = require "lib.squirtle.api-layers.squirtle-basic-api"

---@param side string
return function(side)
    SquirtleBasicApi.dig(side)
    local diskState = DatabaseService.getSquirtleDiskState()
    diskState.shulkerSides = {}
    diskState.cleanupSides[side] = nil
    DatabaseService.saveSquirtleDiskState(diskState)
end
