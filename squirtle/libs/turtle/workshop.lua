---@class Workshop
---@field location Vector
---@field bufferLocation Vector
---@field inputLocation Vector
---@field outputLocation Vector
local Workshop = {}

function Workshop.new()
    local instance = {}

    setmetatable(instance, {__index = Workshop})

    return instance
end



return Workshop
