if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local SubwayService = require "lib.systems.subway.subway-service"
local RemoteService = require "lib.systems.runtime.remote-service"

print(string.format("[subway-switch %s] booting...", version()))

local maxDistance = tonumber(arg[1])

if maxDistance then
    Utils.writeStartupFile(string.format("subway-switch %d", maxDistance))
else
    Utils.writeStartupFile("subway-switch")
end

local defaultMaxDistance = 15
SubwayService.maxDistance = maxDistance or defaultMaxDistance
print("[max-distance]", SubwayService.maxDistance)

RemoteService.addIntParameter({
    id = "subway:max-distance",
    type = "int-parameter",
    name = "Max. Distance",
    get = function()
        return SubwayService.maxDistance
    end,
    set = function(value)
        SubwayService.maxDistance = value or defaultMaxDistance

        if value then
            Utils.writeStartupFile(string.format("subway-switch %d", value))
            return true, string.format("Max. Distance set to %d", SubwayService.maxDistance)
        else
            Utils.writeStartupFile("subway-switch")
            return true, string.format("Max. Distance set to %d (default)", SubwayService.maxDistance)
        end
    end,
    min = 1,
    max = 64,
    nullable = true,
    requiresReboot = true
})

EventLoop.run(function()
    Rpc.host(SubwayService)
end, function()
    RemoteService.run({"subway-switch"})
end)
