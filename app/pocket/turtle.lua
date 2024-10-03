package.path = package.path .. ";/?.lua"

local Vector = require "lib.common.vector"
local Rpc = require "lib.common.rpc"
local SquirtleService = require "lib.squirtle.squirtle-service"

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
