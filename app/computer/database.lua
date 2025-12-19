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
local ApplicationApi = require "lib.system.application-api"
local ApplicationService = require "lib.system.application-service"
local DatabaseService = require "lib.database.database-service"
local TaskService = require "lib.system.task-service"
local SearchableList = require "lib.ui.searchable-list"

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

local Shell = require "lib.system.shell"
local app = Shell.getApplication(arg)

app:addWindow("Apps", function()
    while true do
        local function getApps()
            return {
                ["computer"] = ApplicationService.getApplications("computer"),
                ["pocket"] = ApplicationService.getApplications("pocket"),
                ["turtle"] = ApplicationService.getApplications("turtle")
            }
        end

        local function getListOptions()
            local apps = getApps()

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
            local apps = getApps()

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

app:addWindow("RPC / Upload", function()
    local monitor = peripheral.find("monitor")

    if monitor then
        print("[redirected to monitor]")
        monitor.setTextScale(1.0)
        EventLoop.configure({window = monitor})
    end

    EventLoop.run(function()
        Rpc.host(ApplicationService)
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
                    local platforms = metadata.platform

                    if type(platforms) == "string" then
                        platforms = {platforms}
                    end

                    for _, platform in ipairs(platforms) do
                        table.insert(apps[platform], application)
                        print(string.format("[uploaded] %s/%s %s", platform, application.name, application.version))
                    end
                else
                    print(message)
                end
            end

            for _, platform in pairs(Utils.getPlatforms()) do
                for _, app in pairs(apps[platform]) do
                    ApplicationApi.writeApp(string.format(".kita/app/%s", platform), app)
                end
            end
        end
    end)
end)

if Utils.getPlatform() == "computer" then
    app:addWindow("Boot Disk", function()
        while true do
            os.sleep(1)
            Utils.waitForUserToHitEnter("hit <enter> to create a boot disk")

            while not fs.isDir("disk") do
                Utils.waitForUserToHitEnter("no disk attached. attach one, then hit <enter>")
            end

            print("[creating] boot disk...")

            ---@type string[]
            local paths = {}

            -- create a program file in root so the user can just type "kita" to start kita
            local programFile = fs.open("disk/kita", "w")
            programFile.writeLine("local platform = (pocket and \"pocket\") or (turtle and \"turtle\") or \"computer\"")
            programFile.writeLine("shell.run(string.format(\".kita/app/%s/kita\", platform), table.unpack(arg))")
            programFile.close()
            table.insert(paths, "kita")
            print("[created] disk/kita")

            for _, platform in ipairs(Utils.getPlatforms()) do
                -- create kita app file for each platform
                local kitaApp = ApplicationService.getApplication(platform, "kita", true)
                local path = string.format("disk/.kita/app/%s/kita", platform)
                local kitaAppFile = fs.open(path, "w")
                kitaAppFile.write(kitaApp.content)
                kitaAppFile.close()
                table.insert(paths, string.format(".kita/app/%s/kita", platform))
                print(string.format("[created] %s", path))
            end

            -- create startup file copying over everything and starting kita
            local startupFile = fs.open("disk/startup", "w")

            startupFile.writeLine("if fs.isDir(\"disk\") then")
            for _, path in ipairs(paths) do
                startupFile.writeLine(string.format("    if fs.exists(\"%s\") then fs.delete(\"%s\") end", path, path))
                startupFile.writeLine(string.format("    fs.copy(\"/disk/%s\", \"%s\")", path, path))
            end
            startupFile.writeLine("else")
            -- delete the startup file if not booting from a disk
            startupFile.writeLine("    fs.delete(\"startup\")")
            startupFile.writeLine("end")
            startupFile.close()

            print("[created] disk/startup")
        end
    end)
end

app:addLogsWindow()
app:run()
