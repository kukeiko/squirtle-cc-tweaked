package.path = package.path .. ";/?.lua"
local Rpc = require "lib.common.rpc"
local Print3dService = require "lib.features.print3d-service"

print("[print3d v2.1.0]")
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
