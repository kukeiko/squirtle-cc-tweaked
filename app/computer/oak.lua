if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Shell = require "lib.system.shell"
local RedstoneApi = require "lib.common.redstone"
local OakService = require "lib.farms.oak-service"
local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    while true do
        local oaks = Rpc.all(OakService)
        local isOn = RedstoneApi.hasInput()

        for _, oak in pairs(oaks) do
            if isOn then
                print(string.format("[on] turn on %s", oak.host))
                oak.on()
            else
                print(string.format("[off] turn off %s", oak.host))
                oak.off()
            end
        end

        EventLoop.pull("redstone")
    end
end)

app:addLogsWindow()
app:run()
