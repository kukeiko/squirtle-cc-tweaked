if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Rpc = require "lib.tools.rpc"
local SubwayService = require "lib.transportation.subway-service"
local Shell = require "lib.system.shell"
local EditEntity = require "lib.ui.edit-entity"
local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    print(string.format("[subway-switch %s] booting...", version()))

    -- fixes a bug where we can't set a signal of 0 if chunk unloaded
    print("[refresh] signal")
    local currentSignal = redstone.getAnalogInput("bottom")
    redstone.setAnalogOutput("bottom", 15)
    os.sleep(1)
    redstone.setAnalogOutput("bottom", currentSignal)

    local editEntity = EditEntity.new("Subway Switch Options", ".kita/data/subway-switch.options.json")
    editEntity:addInteger("radius", "Radius", {minValue = 1, maxValue = 64})

    ---@class SubwaySwitchOptions
    ---@field radius integer
    local options = editEntity:run({radius = 16}, app:wasAutorun())
    SubwayService.maxDistance = options.radius

    app:exposeRemoteOptions(editEntity)
    Rpc.host(SubwayService)
end)

app:addLogsWindow()
app:run()
