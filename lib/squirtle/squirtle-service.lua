local Squirtle = require "lib.squirtle.squirtle-api"

---@class SquirtleService : Service
---@field error string?
local SquirtleService = {name = "squirtle", error = nil}

function SquirtleService.locate()
    return Squirtle.locate()
end

---@return string?
function SquirtleService.getError()
    return SquirtleService.error
end

function SquirtleService.shutdown()
    os.shutdown()
end

return SquirtleService
