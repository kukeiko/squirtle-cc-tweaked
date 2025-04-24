if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Rpc = require "lib.tools.rpc"
local BoneMealService = require "lib.systems.farms.bone-meal-service"

print(string.format("[bone-meal %s] booting...", version()))
local on = arg[1] == "on"
local off = arg[1] == "off"
local reboot = arg[1] == "reboot"

local boneMeals = Rpc.all(BoneMealService)

for _, boneMeal in pairs(boneMeals) do
    if on then
        print(string.format("[on] %s", boneMeal.host))
        boneMeal.on()
    elseif off then
        print(string.format("[off] %s", boneMeal.host))
        boneMeal.off()
    elseif reboot then
        boneMeal.reboot()
    else
        local _, _, percentage = boneMeal.getStock()
        print(string.format("[stock] %s", percentage))
    end
end
