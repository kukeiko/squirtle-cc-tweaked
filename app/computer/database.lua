if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "computer"}
end

local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local EventLoop = require "lib.tools.event-loop"
local AppsService = require "lib.system.apps-service"
local DatabaseService = require "lib.database.database-service"
local TaskService = require "lib.system.task-service"
local SearchableList = require "lib.ui.searchable-list"
local logsWindow = require "lib.system.windows.logs-window"

print(string.format("[database %s] booting...", version()))
Utils.writeStartupFile("database")

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

local Shell = require "lib.system.shell"

Shell:addWindow("Apps", function()
    while true do
        local apps = {
            ["computer"] = AppsService.getComputerApps(),
            ["pocket"] = AppsService.getPocketApps(),
            ["turtle"] = AppsService.getTurtleApps()
        }

        local function getListOptions()
            local apps = {
                ["computer"] = AppsService.getComputerApps(),
                ["pocket"] = AppsService.getPocketApps(),
                ["turtle"] = AppsService.getTurtleApps()
            }

            ---@type SearchableListOption[]
            local options = {
                {id = "computer", name = "Computer", suffix = tostring(#apps["computer"])},
                {id = "pocket", name = "Pocket", suffix = tostring(#apps["pocket"])},
                {id = "turtle", name = "Turtle", suffix = tostring(#apps["turtle"])}
            }
            return options
        end

        local list = SearchableList.new(getListOptions(), "Platform", 10, 1, getListOptions)
        local selected = list:run()

        if selected then
            if selected.id == "computer" then
                showApps(apps["computer"], "Computer")
            elseif selected.id == "pocket" then
                showApps(apps["pocket"], "Pocket")
            elseif selected.id == "turtle" then
                showApps(apps["turtle"], "Turtle")
            end
        end
    end
end)

Shell:addWindow("RPC / Upload", function()
    EventLoop.run(function()
        AppsService.run()
    end, function()
        Rpc.host(DatabaseService)
    end, function()
        Rpc.host(TaskService)
    end, function()
        while true do
            local _, files = EventLoop.pull("file_transfer")
            ---@type table<"computer" | "pocket" | "turtle", Application[]>
            local apps = {computer = {}, pocket = {}, turtle = {}}

            for _, file in pairs(files.getFiles()) do
                -- [todo] ❌ support uploading subway-stations.json
                local contents = file.readAll()
                local fn, message = load(contents, "@/" .. file.getName(), nil, {})

                if fn then
                    ---@type ApplicationMetadata
                    local metadata = fn()
                    ---@type Application
                    local application = {name = file.getName(), path = "", version = metadata.version, content = contents}
                    table.insert(apps[metadata.platform], application)
                    print(string.format("[uploaded] %s/%s %s", metadata.platform, application.name, application.version))
                else
                    print(message)
                end
            end

            AppsService.setComputerApps(apps.computer)
            AppsService.setPocketApps(apps.pocket)
            AppsService.setTurleApps(apps.turtle)
        end
    end)
end)

Shell:addWindow("Logs", logsWindow)

EventLoop.run(function()
    Shell:run()
end)

term.clear()
term.setCursorPos(1, 1)
