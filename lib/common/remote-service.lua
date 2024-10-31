local version = require "version"
local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local EventLoop = require "lib.common.event-loop"
local UpdateService = require "lib.common.update-service"

---@class RemoteService : Service
---@field commands RemoteCommand[]
local RemoteService = {name = "remote", commands = {}, updatedApps = {}}

---@param updatedApps? string[]
function RemoteService.run(updatedApps)
    RemoteService.updatedApps = updatedApps or {}

    EventLoop.run(function()
        Rpc.host(RemoteService)
    end, function()
        while true do
            local event = EventLoop.pull()

            if event == "terminate" then
                return
            elseif event == "remote:reboot" then
                os.reboot()
            end
        end
    end)
end

function RemoteService.update()
    UpdateService.update(RemoteService.updatedApps)
end

function RemoteService.reboot()
    EventLoop.queue("remote:reboot")
end

---@return string
function RemoteService.getVersion()
    return version()
end

function RemoteService.getCommands()
    return RemoteService.commands
end

---@param command RemoteIntParameterCommand
function RemoteService.addIntParameter(command)
    table.insert(RemoteService.commands, command)
end

---@param id string
---@return integer?
function RemoteService.getIntParameter(id)
    local command = Utils.find(RemoteService.commands, function(command)
        return command.id == id
    end)

    if not command then
        error(string.format("command %s not found", id))
    elseif command.type ~= "int-parameter" then
        error(string.format("command %s is not an int-parameter command", id))
    end

    command = command --[[@as RemoteIntParameterCommand]]

    return command.get()
end

---@param id string
---@param value? integer
---@return boolean, string?
function RemoteService.setIntParameter(id, value)
    local command = Utils.find(RemoteService.commands, function(command)
        return command.id == id
    end)

    if not command then
        error(string.format("command %s not found", id))
    elseif command.type ~= "int-parameter" then
        error(string.format("command %s is not an int-parameter command", id))
    end

    command = command --[[@as RemoteIntParameterCommand]]

    return command.set(value)
end

return RemoteService
