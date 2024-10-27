if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local SearchableList = require "lib.ui.searchable-list"
local RemoteService = require "lib.common.remote-service"
local readInteger = require "lib.ui.read-integer"

print(string.format("[remote %s]", version()))

---@param remote RemoteService|RpcClient
local function doRebootCommand(remote)
    print("[rebooting] ...")
    remote.reboot()
    os.sleep(1)
    local host = remote.host
    remote = Rpc.client(RemoteService, host)

    while not remote do
        os.sleep(1)
        remote = Rpc.client(RemoteService, host)
    end

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

---@param command RemoteCommand
---@param remote RemoteService|RpcClient
---@return SearchableListOption
local function remoteCommandToListOption(command, remote)
    if command.type == "int-parameter" then
        command = command --[[@as RemoteIntParameterCommand]]
        ---@type SearchableListOption
        local option = {id = command.id, name = command.name, suffix = tostring(remote.getIntParameter(command.id))}

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
        print(string.format("[min] %d, [max] %d, [optional] %s", command.min, command.max, command.nullable))

        local value = readInteger()

        while not value and not command.nullable do
            value = readInteger()
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
        local remote = Rpc.client(RemoteService, host)
        ---@type SearchableListOption[]
        local options = {{id = "reboot", name = "Reboot"}, {id = "update", name = "Update"}}
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
            -- [todo] reboot on kunterbunt storage works but never returns back to the list
            doRebootCommand(remote)
        elseif selected.id == "update" then
            doUpdateCommand(remote)
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

local function showRemotes()
    while true do
        local remotes = Rpc.all(RemoteService)
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

EventLoop.run(function()
    showRemotes()
end)
