if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local UpdateService = require "lib.common.update-service"

print(string.format("[update %s]", version()))
UpdateService.update()
