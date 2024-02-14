package.path = package.path .. ";/lib/?.lua"
local Rpc = require "rpc"
local BoneMealService = require "services.bone-meal-service"

print("[bone-meal v1.0.0] booting...")
local on = arg[1] == "on"
local boneMeals = Rpc.all(BoneMealService)

for _, boneMeal in pairs(boneMeals) do
    if on then
        print(string.format("[on] %s", boneMeal.host))
        boneMeal.on()
    else
        print(string.format("[off] %s", boneMeal.host))
        boneMeal.off()
    end
end

print("[ok] done!")
