if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Logger = require "lib.tools.logger"
local EventLoop = require "lib.tools.event-loop"
local Shell = require "lib.system.shell"
local ItemApi = require "lib.inventory.item-api"
local InventoryApi = require "lib.inventory.inventory-api"
local EditEntity = require "lib.ui.edit-entity"

local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    local editEntity = EditEntity.new("Fungi Farm Options", ".kita/data/fungi-farm.options.json")
    editEntity:addInteger("interval", "Interval", {minValue = 2})
    app:exposeRemoteOptions(editEntity)

    ---@class FungiFarmOptions
    ---@field interval integer
    local options = editEntity:run({interval = 2}, app:wasAutorun())

    EventLoop.run(function()
        while true do
            -- redstone tick to dispense bone meal
            if InventoryApi.getItemCount({"back"}, ItemApi.boneMeal, "input") > 0 then
                redstone.setOutput("back", true)
                os.sleep(2)
                redstone.setOutput("back", false)
                os.sleep(options.interval)
            end
        end
    end, function()
        while true do
            Logger.log("refill bone meal")
            InventoryApi.empty({"bottom"}, {"back"})
            os.sleep(30)
        end
    end)
end)

app:addLogsWindow()
app:run()
