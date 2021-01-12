package.path = package.path .. ";/libs/?.lua"

---@class Workspace
local Workspace = {}

---@return Workspace
function Workspace.create()
    local instance = {}

    setmetatable(instance, {__index = Workspace})

    return instance
end

return Workspace
