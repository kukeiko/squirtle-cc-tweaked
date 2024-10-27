if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local BoneMealService = require "lib.features.bone-meal-service"
local RemoteService = require "lib.common.remote-service"

print(string.format("[bone-meal %s] booting...", version()))
Utils.writeStartupFile("bone-meal")
BoneMealService.off()

EventLoop.run(function()
    Rpc.server(BoneMealService)
end, function()
    BoneMealService.run()
end, function()
    RemoteService.run({"bone-meal"})
end)
