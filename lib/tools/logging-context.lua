---@class LoggingContext
---@field name string
local LoggingContext = {}

---@param name string
function LoggingContext.new(name)
    ---@type LoggingContext
    local instance = {name = name}
    setmetatable(instance, {__index = LoggingContext})

    return instance
end

function LoggingContext:getName()
    return self.name
end

return LoggingContext
