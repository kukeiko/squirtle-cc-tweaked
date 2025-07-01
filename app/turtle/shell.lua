if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local ApplicationApi = require "lib.apis.application-api"
local Shell = require "lib.ui.shell"
local SearchableList = require "lib.ui.searchable-list"

Shell:addWindow("Apps", function()
    while true do
        -- [todo] ❌ only for dev
        local apps = ApplicationApi.getComputerApps()
        -- local apps = ApplicationApi.getTurtleApps()
        local options = Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = app.version}

            return option
        end)

        local list = SearchableList.new(options, "Apps")
        local selected = list:run()

        if selected then
            Shell:launch(selected.id)
        end
    end
end)

Shell:run()
