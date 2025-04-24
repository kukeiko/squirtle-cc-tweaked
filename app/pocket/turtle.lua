if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Vector = require "lib.models.vector"
local Rpc = require "lib.tools.rpc"
local TurtleService = require "lib.systems.turtle-service"

print(string.format("[turtle %s] booting...", version()))
local squirtles = Rpc.all(TurtleService)

for _, squirtle in pairs(squirtles) do
    local name = squirtle.host
    local location = Vector.toString(squirtle.locate())
    local distance = squirtle.distance
    local errorMessage = squirtle.getError()
    local status = "ok"

    if errorMessage then
        status = "error"
    end

    print(string.format("[%s] %s at %s, %dm", status, name, location, distance))

    if errorMessage then
        print(errorMessage)
    end
end
