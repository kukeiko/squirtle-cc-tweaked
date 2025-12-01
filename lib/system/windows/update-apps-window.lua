local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ApplicationApi = require "lib.system.application-api"
local ApplicationService = require "lib.system.application-service"
local SearchableList = require "lib.ui.searchable-list"
local installApp = require "lib.system.functions.install-app"

---@return Application[]
local function getLocalApplications()
    return ApplicationApi.getApplications(Utils.getPlatform())
end

---@param applicationService ApplicationService|RpcClient
---@return Application[]
local function getAvailableApps(applicationService)
    return applicationService.getApplications(Utils.getPlatform())
end

---@param _ ShellWindow
return function(_)
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
end
