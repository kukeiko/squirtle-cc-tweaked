if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local UpdateService = require "lib.system.update-service"

print(string.format("[update %s]", version()))
local app = arg[1]

if app then
    UpdateService.update({app})
else
    UpdateService.update()
end
