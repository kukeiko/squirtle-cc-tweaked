if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local BoneMealService = require "lib.farms.bone-meal-service"

print(string.format("[bone-meal %s]", version()))
print("[connecting] ...")
local boneMeals = Rpc.all(BoneMealService)

for _, boneMeal in pairs(boneMeals) do
    local _, _, percentage = boneMeal.getStock()
    print(string.format("%s %s %s", boneMeal.isOn() and "[on]" or "[off]", boneMeal.host, percentage))
end

Utils.waitForUserToHitEnter()
