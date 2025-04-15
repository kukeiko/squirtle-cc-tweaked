local DatabaseApi = require "lib.apis.database.database-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"

---@param side string
return function(side)
    -- [todo] assert that there is a shulker?
    TurtleMiningApi.dig(side)
    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.shulkerSides = {}
    diskState.cleanupSides[side] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)
end
