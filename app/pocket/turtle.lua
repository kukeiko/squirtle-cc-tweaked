package.path = package.path .. ";/lib/?.lua"

local Vector = require "elements.vector"
local Rpc = require "rpc"
local SquirtleService = require "services.squirtle-service"

print("[turtle v1.0.0] booting...")
local squirtles = Rpc.all(SquirtleService)

for _, squirtle in pairs(squirtles) do
    local name = squirtle.host
    local location = Vector.toString(squirtle.locate(true))
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
