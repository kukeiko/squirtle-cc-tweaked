package.path = package.path .. ";/?.lua"
local Rpc = require "lib.rpc"
local BoneMealService = require "lib.services.bone-meal-service"

print("[bone-meal v2.0.0-dev] booting...")
BoneMealService.off()
Rpc.server(BoneMealService)
