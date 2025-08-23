if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Rpc = require "lib.tools.rpc"
local OakService = require "lib.farms.oak-service"

print(string.format("[oak %s] booting...", version()))
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
