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
local BoneMealService = require "lib.systems.farms.bone-meal-service"
local RemoteService = require "lib.systems.runtime.remote-service"

print(string.format("[bone-meal %s] booting...", version()))
Utils.writeStartupFile("bone-meal")
BoneMealService.off()

EventLoop.run(function()
    Rpc.host(BoneMealService)
end, function()
    BoneMealService.run()
end, function()
    RemoteService.run({"bone-meal"})
end)
