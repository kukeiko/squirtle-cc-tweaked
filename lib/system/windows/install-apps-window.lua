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
end
