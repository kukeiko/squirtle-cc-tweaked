if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local UpdateService = require "lib.systems.runtime.update-service"

print(string.format("[update %s]", version()))
UpdateService.update()
