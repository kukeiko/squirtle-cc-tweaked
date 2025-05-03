if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemApi = require "lib.apis.item-api"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local RemoteService = require "lib.systems.runtime.remote-service"

print(string.format("[fungi-farm %s] booting...", version()))
local interval = math.max(2, tonumber(arg[1]) or 2)
print("[interval]", interval)
Utils.writeStartupFile(string.format("fungi-farm %d", interval))

EventLoop.run(function()
    RemoteService.run({"fungi-farm"})
end, function()
    while true do
        if InventoryApi.getItemCount({"back"}, ItemApi.boneMeal, "input") > 0 then
            redstone.setOutput("back", true)
            os.sleep(2)
            redstone.setOutput("back", false)
            os.sleep(interval)
        end
    end
end, function()
    while true do
        InventoryApi.empty({"bottom"}, {"back"})
        os.sleep(30)
    end
end)
