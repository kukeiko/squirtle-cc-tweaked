if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local SearchableList = require "lib.ui.searchable-list"
local RemoteService = require "lib.systems.runtime.remote-service"
local Shell = require "lib.ui.shell"
local readInteger = require "lib.ui.read-integer"

print(string.format("[remote %s]", version()))

---@param remote RemoteService|RpcClient
local function doRebootCommand(remote)
    print("[rebooting] ...")
    remote.reboot()
    Rpc.connect(RemoteService, remote.host)
    print("[rebooted] done!")
    os.sleep(1)
end

---@param remote RemoteService|RpcClient
local function doUpdateCommand(remote)
    print("[updating] ...")
    remote.update()
    print("[updated] done!")
    os.sleep(1)
end

---@param remote RemoteService|RpcClient
local function doUpdateRebootCommand(remote)
    doUpdateCommand(remote)
    doRebootCommand(remote)
end

---@param command RemoteCommand
---@param remote RemoteService|RpcClient
---@return SearchableListOption
local function remoteCommandToListOption(command, remote)
    if command.type == "int-parameter" then
        command = command --[[@as RemoteIntParameterCommand]]
        ---@type SearchableListOption
        local option = {id = command.id, name = command.name, suffix = tostring(remote.getIntParameter(command.id) or nil)}

        return option
    else
        error(string.format("unknown command type %s", command.type))
    end
end

---@param command RemoteCommand
---@param remote RemoteService|RpcClient
local function runCommand(command, remote)
    if command.type == "int-parameter" then
        command = command --[[@as RemoteIntParameterCommand]]

        print(string.format("[prompt] enter new value for %s", command.name))
        local hints = {}

        if command.min then
            table.insert(hints, string.format("[min] %d", command.min))
        end

        if command.max then
            table.insert(hints, string.format("[max] %d", command.max))
        end

        table.insert(hints, string.format("[optional] %s", command.nullable))
        print(table.concat(hints, ", "))

        local value = readInteger()

        while not value and not command.nullable do
            value = readInteger(value, {min = command.min, max = command.max})
        end

        local succees, message = remote.setIntParameter(command.id, value)

        if not succees then
            print(string.format("[error] %s", message or "(unknown)"))
        else
            print(string.format("[success] %s", message or "value set!"))
        end

        Utils.waitForUserToHitEnter("(hit enter to continue)")
    else
        error(string.format("unknown command type %s", command.type))
    end
end

---@param host string
local function showCommands(host)
    while true do
        local remote = Rpc.connect(RemoteService, host)
        ---@type SearchableListOption[]
        local options = {
            {id = "reboot", name = "Reboot"},
            {id = "update", name = "Update"},
            {id = "update-reboot", name = "Update & Reboot"}
        }
        local commands = remote.getCommands()

        for _, command in pairs(commands) do
            table.insert(options, remoteCommandToListOption(command, remote))
        end

        local list = SearchableList.new(options, string.format("%s %s", remote.host, remote.getVersion()))
        local selected = list:run()

        if not selected then
            return
        end

        term.clear()
        term.setCursorPos(1, 1)

        if selected.id == "reboot" then
            doRebootCommand(remote)
        elseif selected.id == "update" then
            doUpdateCommand(remote)
        elseif selected.id == "update-reboot" then
            doUpdateRebootCommand(remote)
        else
            local command = Utils.find(commands, function(command)
                return command.id == selected.id
            end)

            if command then
                runCommand(command, remote)
            end
        end
    end
end

---@param timeout number?
local function showRemotes(timeout)
    while true do
        local remotes = Rpc.all(RemoteService, timeout)
        local options = Utils.map(remotes, function(item)
            ---@type SearchableListOption
            local option = {id = item.host, name = item.host, suffix = item.getVersion()}

            return option
        end)

        table.sort(options, function(a, b)
            return a.name < b.name
        end)

        local searchableList = SearchableList.new(options)
        local selected = searchableList:run()

        if not selected then
            return
        end

        showCommands(selected.id)
    end
end

---@param timeout integer?
local function showBatch(timeout)
    while true do
        ---@type SearchableListOption[]
        local options = {
            {id = "reboot", name = "Reboot"},
            {id = "update", name = "Update"},
            {id = "update-reboot", name = "Update & Reboot"}
        }
        local searchableList = SearchableList.new(options)
        local selected = searchableList:run()

        if selected then
            local remotes = Rpc.all(RemoteService, timeout)
            print(string.format("[%s] run on %d remotes", selected.id, #remotes))

            for _, remote in pairs(remotes) do
                local doUpdate = selected.id == "update" or selected.id == "update-reboot"
                local doReboot = selected.id == "reboot" or selected.id == "update-reboot"

                if doUpdate then
                    print(string.format("[updating] %s...", remote.host))
                    remote.update()
                    print(string.format("[updated] %s", remote.host))
                end

                if doReboot then
                    print(string.format("[rebooting] %s...", remote.host))
                    remote.reboot()
                    print(string.format("[rebooted] %s", remote.host))
                end
            end
        end
    end
end

EventLoop.run(function()
    local timeout = tonumber(arg[1]) or nil

    Shell:addWindow("Remotes", function()
        showRemotes(timeout)
    end)

    Shell:addWindow("Batch", function()
        showBatch(timeout)
    end)

    Shell:run()
end)

term.clear()
term.setCursorPos(1, 1)
