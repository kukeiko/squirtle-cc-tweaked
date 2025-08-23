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
local ApplicationApi = require "lib.system.application-api"
local Shell = require "lib.system.shell"
local SearchableList = require "lib.ui.searchable-list"

Shell:addWindow("Apps", function()
    ApplicationApi.initAppVersions()
    -- [todo] ❌ only for dev
    local apps = ApplicationApi.getComputerApps()
    -- local apps = ApplicationApi.getTurtleApps()
    local function getOptions()
        return Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = Shell:isRunning(app.path) and "\07" or " "}

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
    end)
end)

Shell:run()

