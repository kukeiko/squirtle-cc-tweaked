local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local SearchableList = require "lib.ui.searchable-list"

---@param shellWindow ShellWindow
return function(shellWindow)
    local apps = shellWindow:getShell():getInstalled(true)

    local function getOptions()
        return Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.name, name = app.name, suffix = shellWindow:getShell():isRunning(app.name) and "\07" or " "}

            return option
        end)
    end

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
            apps = shellWindow:getShell():getInstalled(true)
            list:setOptions(getOptions())
        end
    end)
end
