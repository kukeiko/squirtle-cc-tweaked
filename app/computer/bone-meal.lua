package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local BoneMealService = require "services.bone-meal-service"

print("[bone-meal v1.2.0] booting...")
BoneMealService.host = os.getComputerLabel()
print("[host]", BoneMealService.host)
BoneMealService.off()
Rpc.server(BoneMealService)
