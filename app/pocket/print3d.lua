if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Rpc = require "lib.tools.rpc"
local Print3dService = require "lib.building.print3d-service"

print(string.format("[print3d %s]", version()))

local on = arg[1] == "on"
local off = arg[1] == "off"
local abort = arg[1] == "abort"
local printers = Rpc.all(Print3dService)

for _, printer in pairs(printers) do
    if on then
        print(string.format("[on] %s", printer.host))
        printer.on()
    elseif off then
        print(string.format("[off] %s", printer.host))
        printer.off()
    elseif abort then
        print(string.format("[abort] %s", printer.host))
        printer.abort()
    end
end
