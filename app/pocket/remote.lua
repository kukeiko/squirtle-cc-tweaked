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
local Shell = require "lib.system.shell"
local ShellService = require "lib.system.shell-service"
local EntitySchema = require "lib.common.entity-schema"
local SearchableList = require "lib.ui.searchable-list"
local readInteger = require "lib.ui.read-integer"
local EditEntity = require "lib.ui.edit-entity"

local app = Shell.getApplication(arg)

---@param remote ShellService|RpcClient
local function doRebootCommand(remote)
    print("[rebooting] ...")
    remote.reboot()
    Rpc.connect(ShellService, remote.host)
    print("[rebooted] done!")
    os.sleep(1)
end

---@param remote ShellService|RpcClient
local function doUpdateCommand(remote)
    print("[updating] ...")
    remote.update()
    print("[updated] done!")
    os.sleep(1)
end

---@param remote ShellService|RpcClient
local function doUpdateRebootCommand(remote)
    doUpdateCommand(remote)
    doRebootCommand(remote)
end

---@param remote ShellService|RpcClient
local function doLocateCommand(remote)
    EventLoop.waitForAny(function()
        print("[trying] to get position...")
        local position = remote.tryGetLivePosition()

        while true do
            term.setCursorPos(1, 1)
            term.clear()

            local x, y, z, distance = "N/A", "N/A", "N/A", "N/A"

            if position then
                x = tostring(position.x)
                y = tostring(position.y)
                z = tostring(position.z)
            end

            if remote.distance then
                distance = tostring(math.floor(remote.distance)) .. "m"
            end

            print(string.format("X: %s", x))
            print(string.format("Y: %s", y))
            print(string.format("Z: %s", z))
            print(string.format("Distance: %s", distance))

            os.sleep(1)
            position = remote.tryGetLivePosition()
        end
    end, function()
        EventLoop.pullKey(keys.f4)
    end)
end

---@param remote ShellService|RpcClient
---@param optionName string
local function doOptionCommand(remote, optionName)
    local entity, schema = remote.getOptions(optionName)
    setmetatable(schema, {__index = EntitySchema})
    local editEntity = EditEntity.new(optionName)
    -- [todo] ❌ dirty
    editEntity.schema = schema

    while true do
        local changed = editEntity:run(entity)

        if not changed then
            return
        end

        local errors = remote.setOptions(optionName, changed)

        if not errors then
            return
        end

        -- [todo] ❌ somehow set the errors
    end
end

---@param host string
local function showRemoteCommands(host)
    while true do
        local remote = Rpc.connect(ShellService, host)

        ---@type SearchableListOption[]
        local options = {
            {id = "reboot", name = "Reboot"},
            {id = "update", name = "Update"},
            {id = "update-reboot", name = "Update & Reboot"},
            {id = "locate", name = "Locate"}
        }

        local remoteOptions = remote.getOptionNames()

        for _, optionName in ipairs(remoteOptions) do
            ---@type SearchableListOption
            local option = {id = string.format("option-%s", optionName), name = optionName, data = optionName}
            table.insert(options, option)
        end

        -- local commands = remote.getCommands()

        -- for _, command in pairs(commands) do
        --     table.insert(options, commandToOption(command, remote))
        -- end

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
        elseif selected.id == "locate" then
            doLocateCommand(remote)
        elseif Utils.startsWith(selected.id, "option-") then
            doOptionCommand(remote, selected.data)
        end
    end
end

app:addWindow("Remotes", function(shellWindow)
    ---@type (ShellService|RpcClient)[]
    local services = {}

    EventLoop.run(function()
        for discovered in Rpc.discover(ShellService) do
            table.insert(services, discovered)
        end
    end, function()
        ---@return SearchableListOption[]
        local function getOptions()
            return Utils.map(services, function(service)
                ---@type SearchableListOption
                local option = {id = service.host, name = service.host}

                if service.ping() and service.distance then
                    option.suffix = string.format("%sm", math.floor(service.distance))
                else
                    option.suffix = "N/A"
                end

                return option
            end)
        end

        local list = SearchableList.new(getOptions(), "Remotes", nil, 1, getOptions)

        while true do
            local selected = list:run()

            if selected then
                showRemoteCommands(selected.id)
            end
        end
    end)
end)

app:addWindow("Services", function(shellWindow)
    while true do
        print("[todo] add window where user can select from a list of services")
        print("when a service is selected, show all remotes that have that service running and show some stats (like bone-meal stock %)")
        os.sleep(10000)
    end
end)

app:addLogsWindow()

app:run()

-- ---@param timeout integer?
-- local function showBatch(timeout)
--     while true do
--         ---@type SearchableListOption[]
--         local options = {
--             {id = "reboot", name = "Reboot"},
--             {id = "update", name = "Update"},
--             {id = "update-reboot", name = "Update & Reboot"}
--         }
--         local searchableList = SearchableList.new(options)
--         local selected = searchableList:run()

--         if selected then
--             local remotes = Rpc.all(RemoteService, timeout)
--             print(string.format("[%s] run on %d remotes", selected.id, #remotes))

--             for _, remote in pairs(remotes) do
--                 local doUpdate = selected.id == "update" or selected.id == "update-reboot"
--                 local doReboot = selected.id == "reboot" or selected.id == "update-reboot"

--                 if doUpdate then
--                     print(string.format("[updating] %s...", remote.host))
--                     remote.update()
--                     print(string.format("[updated] %s", remote.host))
--                 end

--                 if doReboot then
--                     print(string.format("[rebooting] %s...", remote.host))
--                     remote.reboot()
--                     print(string.format("[rebooted] %s", remote.host))
--                 end
--             end
--         end
--     end
-- end
