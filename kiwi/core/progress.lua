---@class KiwiProgress
---@field min integer
---@field max integer
---@field current integer
local KiwiProgress = {}

---@param min integer
---@param max integer
---@param current integer
function KiwiProgress.new(min, max, current)
    ---@type KiwiProgress
    local instance = {min = min, max = max, current = current}
    return KiwiProgress.cast(instance)
end

---@param data table
---@return KiwiProgress
function KiwiProgress.cast(data)
    setmetatable(data, {__index = KiwiProgress})

    return data
end

function KiwiProgress.castStrict(data, msg)
    if type(data) ~= "table" or type(data.min) ~= "number" or type(data.max) ~= "number" or
        type(data.progress) ~= "number" then
        error(msg)
    end

    return KiwiProgress.cast(data)
end

return KiwiProgress
