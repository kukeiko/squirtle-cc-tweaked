package.path = package.path .. ";/?.lua"
local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local BoneMealService = require "lib.features.bone-meal-service"

print("[bone-meal v2.1.0-dev-1] booting...")
Utils.writeStartupFile("update", "bone-meal")
BoneMealService.off()

EventLoop.run(function()
    Rpc.server(BoneMealService)
end, function()
    BoneMealService.run()
end)
