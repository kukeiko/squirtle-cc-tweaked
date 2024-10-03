local Squirtle = require "lib.squirtle"

---@class SquirtleService : Service
---@field error string?
local SquirtleService = {name = "squirtle", error = nil}

---@param refresh boolean?
function SquirtleService.locate(refresh)
    return Squirtle.locate(refresh)
end

---@return string?
function SquirtleService.getError()
    return SquirtleService.error
end

function SquirtleService.shutdown()
    os.shutdown()
end

return SquirtleService
