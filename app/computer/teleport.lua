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
local RemoteService = require "lib.systems.runtime.remote-service"
local TeleportService = require "lib.systems.teleport-service"

local sides = {"left", "right", "top"}

for i, side in pairs(sides) do
    local pdaId = tonumber(arg[i])
    print(string.format("[%s] PDA = %s", side, tostring(pdaId)))
    TeleportService.setPdaId(side, pdaId)
end

local function writeStartupFile()
    local left = tostring(TeleportService.getPdaId("left"))
    local right = tostring(TeleportService.getPdaId("right"))
    local top = tostring(TeleportService.getPdaId("top"))
    Utils.writeStartupFile(string.format("teleport %s %s %s", left, right, top))
end

writeStartupFile()

for _, side in pairs(sides) do
    RemoteService.addIntParameter({
        id = string.format("teleport:%s-computer-id", side),
        type = "int-parameter",
        name = string.format("PDA Id %s", side),
        get = function()
            return TeleportService.getPdaId(side)
        end,
        set = function(value)
            TeleportService.setPdaId(side, value)
            writeStartupFile()
            return true, string.format("PDA Id %s set to %s", side, tostring(value))
        end,
        min = 1,
        nullable = true,
        requiresReboot = true
    })
end

EventLoop.run(function()
    RemoteService.run({"teleport"})
end, function()
    Rpc.host(TeleportService)
end)
