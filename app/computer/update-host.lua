if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local EventLoop = require "lib.tools.event-loop"
local AppsService = require "lib.systems.runtime.apps-service"
local DatabaseService = require "lib.systems.database.database-service"
local TaskService = require "lib.systems.task.task-service"
local SearchableList = require "lib.ui.searchable-list"

print(string.format("[update-host %s] booting...", version()))
Utils.writeStartupFile("update-host")

---@param apps Application[]
---@param title string
local function showApps(apps, title)
    local options = Utils.map(apps, function(app)
        ---@type SearchableListOption
        local option = {id = app.name, name = app.name, suffix = app.version}

        return option
    end)

    local list = SearchableList.new(options, title)

    while true do
        local selected = list:run()

        if not selected then
            return
        end
    end
end

local monitor = peripheral.find("monitor")

if monitor then
    monitor.setTextScale(1.0)
    term.redirect(monitor)
end

EventLoop.run(function()
    AppsService.run()
end, function()
    Rpc.host(DatabaseService)
end, function()
    Rpc.host(TaskService)
end, function()
    -- [todo] commented out to see task output
    -- while true do
    --     local apps = {
    --         ["computer"] = AppsService.getComputerApps(),
    --         ["pocket"] = AppsService.getPocketApps(),
    --         ["turtle"] = AppsService.getTurtleApps()
    --     }

    --     ---@type SearchableListOption[]
    --     local options = {
    --         {id = "computer", name = "Computer", suffix = tostring(#apps["computer"])},
    --         {id = "pocket", name = "Pocket", suffix = tostring(#apps["pocket"])},
    --         {id = "turtle", name = "Turtle", suffix = tostring(#apps["turtle"])}
    --     }

    --     local list = SearchableList.new(options, "Platform")
    --     local selected = list:run()

    --     if selected then
    --         if selected.id == "computer" then
    --             showApps(apps["computer"], "Computer")
    --         elseif selected.id == "pocket" then
    --             showApps(apps["pocket"], "Pocket")
    --         elseif selected.id == "turtle" then
    --             showApps(apps["turtle"], "Turtle")
    --         end
    --     end
    -- end
end)
