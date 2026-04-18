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
local EditEntity = require "lib.ui.edit-entity"
local TeleportService = require "lib.transportation.teleport-service"

local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    local editEntity = EditEntity.new("Teleport Options", ".kita/data/teleport.options.json")
    editEntity:addInteger("left", "PDA Id #1", {optional = true})
    editEntity:addInteger("right", "PDA Id #2", {optional = true})
    editEntity:addInteger("top", "PDA Id #3", {optional = true})
    app:exposeRemoteOptions(editEntity)

    ---@class TeleportOptions
    ---@field left integer?
    ---@field right integer?
    ---@field top integer?
    local options = editEntity:run({}, app:wasAutorun())

    if options.left then
        TeleportService.setPdaId("left", options.left)
    end

    if options.top then
        TeleportService.setPdaId("top", options.left)
    end

    if options.right then
        TeleportService.setPdaId("right", options.left)
    end

    Rpc.host(TeleportService)
end)

app:addLogsWindow()
app:run()
