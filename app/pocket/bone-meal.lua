package.path = package.path .. ";/?.lua"
local Rpc = require "lib.rpc"
local BoneMealService = require "lib.services.bone-meal-service"

print("[bone-meal v1.2.0] booting...")
local on = arg[1] == "on"
local off = arg[1] == "off"
local boneMeals = Rpc.all(BoneMealService)

for _, boneMeal in pairs(boneMeals) do
    if on then
        print(string.format("[on] %s", boneMeal.host))
        boneMeal.on()
    elseif off then
        print(string.format("[off] %s", boneMeal.host))
        boneMeal.off()
    else
        local _, _, percentage = boneMeal.getStock()
        print(string.format("[stock] %s", percentage))
    end
end
