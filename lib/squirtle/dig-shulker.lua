local DatabaseApi = require "lib.apis.database.database-api"
local SquirtleBasicApi = require "lib.squirtle.api-layers.squirtle-basic-api"

---@param side string
return function(side)
    SquirtleBasicApi.dig(side)
    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.shulkerSides = {}
    diskState.cleanupSides[side] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)
end
