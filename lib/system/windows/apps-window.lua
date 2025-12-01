local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ApplicationApi = require "lib.system.application-api"
local SearchableList = require "lib.ui.searchable-list"

---@return Application[]
local function getLocalApplications()
    return ApplicationApi.getApplications(Utils.getPlatform())
end

---@param shellWindow ShellWindow
return function(shellWindow)
    ApplicationApi.initializeVersions()
    local apps = getLocalApplications()

    local function getOptions()
        return Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.name, name = app.name, suffix = shellWindow:getShell():isRunning(app.name) and "\07" or " "}

            return option
        end)
    end

    -- local autorunViaArg = arg[1] and Utils.find(apps, function(candidate)
    --     return candidate.name == arg[1]
    -- end)

    -- if autorunViaArg then
    --     shellWindow:getShell():addAutorun(autorunViaArg.name)
    -- end

    -- local autoruns = Utils.map(shellWindow:getShell():getAutorun(), function(name)
    --     local app = Utils.find(apps, function(candidate)
    --         return candidate.name == name
    --     end)

    --     if app then
    --         return function()
    --             shellWindow:getShell():launch(app.name)
    --         end
    --     else
    --         return function()
    --             -- do nothing
    --         end
    --     end
    -- end)

    local list = SearchableList.new(getOptions(), "Apps")

    EventLoop.run(function()
        while true do
            local selected, action = list:run()

            if selected and action == "select" then
                shellWindow:getShell():launch(selected.id)
            elseif selected and action == "delete" then
                shellWindow:getShell():terminate(selected.id)
            end
        end
    end, function()
        while true do
            shellWindow:getShell():pullApplicationStateChange()
            list:setOptions(getOptions())
        end
    end, function()
        while true do
            EventLoop.pull("shell:app-installed")
            apps = getLocalApplications()
            list:setOptions(getOptions())
        end
    end)
    -- end, table.unpack(autoruns))
end
