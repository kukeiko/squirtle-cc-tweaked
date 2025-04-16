local TurtleApi = require "lib.apis.turtle.turtle-api"

---@class TurtleService : Service
---@field error string?
local TurtleService = {name = "squirtle", error = nil}

function TurtleService.locate()
    return TurtleApi.locate()
end

---@return string?
function TurtleService.getError()
    return TurtleService.error
end

function TurtleService.shutdown()
    os.shutdown()
end

return TurtleService
