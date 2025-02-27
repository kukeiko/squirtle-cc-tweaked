if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local UpdateService = require "lib.services.update-service"

print(string.format("[update %s]", version()))
local app = arg[1]

if app then
    UpdateService.update({app})
else
    UpdateService.update()
end
