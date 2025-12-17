if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Rpc = require "lib.tools.rpc"
local Shell = require "lib.system.shell"
local BoneMealService = require "lib.farms.bone-meal-service"
local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    while true do
        local isFull, stock, percentage = BoneMealService.getStock()

        if isFull and BoneMealService.isOn() then
            print(string.format("[off] stock is at %s (%dx bone meal)", percentage, stock))
            BoneMealService.off()
        elseif not isFull and not BoneMealService.isOn() then
            print(string.format("[on] stock is at %s (%dx bone meal)", percentage, stock))
            BoneMealService.on()
        end

        os.sleep(30)
    end
end)

app:addWindow("RPC", function()
    Rpc.host(BoneMealService)
end)

app:addLogsWindow()
app:run()
