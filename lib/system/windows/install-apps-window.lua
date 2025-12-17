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
            shellWindow:getShell():install(selected.name, applicationService)
            list:setOptions(getOptions())
        end
    end
end
