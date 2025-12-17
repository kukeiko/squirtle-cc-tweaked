local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local ApplicationService = require "lib.system.application-service"
local SearchableList = require "lib.ui.searchable-list"

---@param shellWindow ShellWindow
return function(shellWindow)
    print("[connect] to application service...")
    local applicationService = Rpc.nearest(ApplicationService)

    local function getOptions()
        local installed = shellWindow:getShell():getInstalled()
        local available = applicationService.getApplications(Utils.getPlatform())
        local availableByName = Utils.toMap(available, function(item)
            return item.name
        end)

        local different = Utils.filter(installed, function(installedApp)
            local match = availableByName[installedApp.name]

            return match and match.version ~= installedApp.version or false
        end)

        return Utils.map(different, function(app)
            local localVersion = app.version
            local remoteVersion = availableByName[app.name].version

            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = string.format("%s > %s", localVersion, remoteVersion)}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Update")

    while true do
        local selected = list:run()

        if selected then
            shellWindow:getShell():install(selected.name, applicationService)
            list:setOptions(getOptions())
        end
    end
end
