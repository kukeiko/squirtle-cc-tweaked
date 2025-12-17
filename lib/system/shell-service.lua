local version = require "version"
local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local EventLoop = require "lib.tools.event-loop"
local ApplicationService = require "lib.system.application-service"
local Vector = require "lib.common.vector"

---@class ShellService : Service
---@field shell Shell
local ShellService = {name = "shell"}

---@param shell Shell
function ShellService.run(shell)
    ShellService.shell = shell

    EventLoop.run(function()
        Rpc.host(ShellService, "wireless")
    end, function()
        while true do
            local event = EventLoop.pull()

            if event == "terminate" then
                return
            elseif event == "shell:reboot" then
                os.reboot()
            end
        end
    end)
end

---@return string[]
function ShellService.getOptionNames()
    return Utils.getKeys(ShellService.shell.remoteOptions)
end

---@param name string
---@return table, EntitySchema
function ShellService.getOptions(name)
    local editEntity = ShellService.shell.remoteOptions[name]

    if not editEntity then
        error(string.format("no options found for %s", name))
    end

    -- [todo] ❌ dirty!
    local saved = Utils.readJson(editEntity.savePath) or {}
    return saved, editEntity:getSchema()
end

---@param name string
---@param entity table
---@return table<string, string>?
function ShellService.setOptions(name, entity)
    local editEntity = ShellService.shell.remoteOptions[name]

    if not editEntity then
        error(string.format("no options found for %s", name))
    end

    local errors = editEntity:validate(entity)

    if not Utils.isEmpty(errors) then
        return errors
    end

    -- [todo] ❌ dirty!
    Utils.writeJson(editEntity.savePath, entity)
end

function ShellService.reboot()
    EventLoop.queue("shell:reboot")
end

function ShellService.update()
    local installed = ShellService.shell.getInstalled()
    local applicationService = Rpc.nearest(ApplicationService)

    for _, app in ipairs(installed) do
        ShellService.shell.install(app.name, applicationService)
    end
end

---@param name string
function ShellService.install(name)
    local applicationService = Rpc.nearest(ApplicationService)
    ShellService.shell.install(name, applicationService)
end

---@return string
function ShellService.getVersion()
    return version()
end

---@return Vector?
function ShellService.tryGetLivePosition()
    local x, y, z = gps.locate()

    if not x then
        return nil
    end

    return Vector.create(x, y, z)
end

return ShellService
