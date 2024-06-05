package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local BoneMealService = require "services.bone-meal-service"

print("[bone-meal v2.0.0-dev] booting...")
BoneMealService.off()
Rpc.server(BoneMealService)
