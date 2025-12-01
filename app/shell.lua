if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local ApplicationApi = require "lib.system.application-api"
local ApplicationService = require "lib.system.application-service"
local Shell = require "lib.system.shell"
local SearchableList = require "lib.ui.searchable-list"

---@return Application[]
local function getLocalApplications()
    return ApplicationApi.getApplications(Utils.getPlatform())
end

---@param applicationService ApplicationService|RpcClient
---@return Application[]
local function getAvailableApps(applicationService)
    return applicationService.getApplications(Utils.getPlatform())
end

---@param applicationService ApplicationService|RpcClient
---@param name string
local function installApp(applicationService, name)
    local platform = Utils.getPlatform()
    local app = applicationService.getApplication(platform, name, true)
    ApplicationApi.addApplications(platform, {app}, false)
    EventLoop.queue("shell:app-installed")
end

Shell:addWindow("Apps", function()
    ApplicationApi.initializeVersions()
    local apps = getLocalApplications()

    local function getOptions()
        return Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.name, name = app.name, suffix = Shell:isRunning(app.name) and "\07" or " "}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Apps")

    EventLoop.run(function()
        while true do
            local selected, action = list:run()

            if selected and action == "select" then
                Shell:launch(selected.id)
            elseif selected and action == "delete" then
                Shell:terminate(selected.id)
            end
        end
    end, function()
        while true do
            Shell:pullApplicationStateChange()
            list:setOptions(getOptions())
        end
    end, function()
        while true do
            EventLoop.pull("shell:app-installed")
            apps = getLocalApplications()
            list:setOptions(getOptions())
        end
    end)
end)

Shell:addWindow("Update", function()
    print("[connect] to application service...")
    local applicationService = Rpc.nearest(ApplicationService)

    local function getOptions()
        local installed = getLocalApplications()
        local available = Utils.toMap(getAvailableApps(applicationService), function(item)
            return item.name
        end)

        local different = Utils.filter(installed, function(installedApp)
            local availableMatch = available[installedApp.name]

            return availableMatch and availableMatch.version ~= installedApp.version or false
        end)

        return Utils.map(different, function(app)
            local localVersion = app.version
            local remoteVersion = available[app.name].version

            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = string.format("%s > %s", localVersion, remoteVersion)}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Update")

    while true do
        local selected = list:run()

        if selected then
            installApp(applicationService, selected.name)
            list:setOptions(getOptions())
        end
    end
end)

Shell:addWindow("Install", function()
    print("[connect] to application service...")
    local applicationService = Rpc.nearest(ApplicationService)

    local function getOptions()
        local installed = getLocalApplications()
        local available = getAvailableApps(applicationService)
        local missing = Utils.filter(available, function(availableCandidate)
            return not Utils.find(installed, function(installedCandidate)
                return installedCandidate.name == availableCandidate.name
            end)
        end)

        return Utils.map(missing, function(app)
            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = app.version}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Install")

    while true do
        local selected = list:run()

        if selected then
            installApp(applicationService, selected.name)
            list:setOptions(getOptions())
        end
    end
end)

Shell:run()
