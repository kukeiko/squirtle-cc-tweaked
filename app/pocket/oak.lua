package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local OakService = require "lib.features.oak-service"

print("[oak v1.0.0-dev]")
local on = arg[1] == "on"
local off = arg[1] == "off"
local oaks = Rpc.all(OakService)

for _, oak in pairs(oaks) do
    if on then
        print(string.format("[on] %s", oak.host))
        oak.on()
    elseif off then
        print(string.format("[off] %s", oak.host))
        oak.off()
    end
end