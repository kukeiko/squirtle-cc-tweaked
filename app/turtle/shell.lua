if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local AppsService = require "lib.systems.runtime.apps-service"
local SearchableList = require "lib.ui.searchable-list"

---@param event string
---@return boolean
local function isUiEvent(event)
    return event == "char" or event == "key" or event == "key_up" or event == "paste"
end

---@type RunningApplication?
local activeApp = nil
---@type RunningApplication[]
local activeApps = {}
local appListWindow = window.create(term.current(), 1, 1, term.getSize())
local showingAppList = true
local rootWindow = term.current()
local apps = AppsService.getTurtleApps()

local function switchToAppSelection()
    while true do
        local _, key = EventLoop.pull("key")

        if key == keys.tab then
            showingAppList = true

            if activeApp then
                activeApp.window.setVisible(false)
            end

            appListWindow.setVisible(true)
        end
    end
end

local function appSelection()
    EventLoop.configure({
        accept = function(event)
            if isUiEvent(event) then
                return showingAppList
            else
                return true
            end
        end,
        window = appListWindow
    })
    while true do
        local options = Utils.map(apps, function(app)
            ---@type SearchableListOption
            local option = {id = app.path, name = app.name, suffix = app.version}

            return option
        end)

        local list = SearchableList.new(options, "Apps")
        local selected = list:run()

        if selected then
            appListWindow.setVisible(false)
            EventLoop.queue("shell:start-app", selected.id)
        end
    end
end

local function appStarter()
    while true do
        ---@param appPath string
        EventLoop.pull("shell:start-app", function(_, appPath)
            showingAppList = false
            local match = Utils.find(activeApps, function(activeApp)
                return activeApp.application.path == appPath
            end)

            if activeApp and activeApp ~= match then
                activeApp.window.setVisible(false)
            end

            if match then
                activeApp = match
                activeApp.window.setVisible(true)
                return
            end

            local application = Utils.find(apps, function(candidate)
                return candidate.path == appPath
            end)

            if not application then
                error(string.format("application %s doesn't exist", appPath))
            end

            ---@type RunningApplication
            local runningApp = {application = application, window = window.create(rootWindow, 1, 1, rootWindow.getSize())}
            activeApp = runningApp

            EventLoop.configure({
                accept = function(event)
                    if isUiEvent(event) then
                        return runningApp == activeApp and not showingAppList
                    else
                        return true
                    end
                end,
                window = runningApp.window
            })

            local file = fs.open(application.path, "r")
            local contents = file.readAll()
            file.close()
            local env = setmetatable({arg = {}}, {__index = _ENV})
            local fn, message = load(contents, "@/" .. application.path, nil, env)

            if not fn then
                error(message)
            end

            table.insert(activeApps, runningApp)
            -- [todo] hack so that configured window gets redirected to before app start.
            -- not yet sure how to solve @ EventLoop
            os.sleep(.25)
            fn()

            Utils.waitForUserToHitEnter("<hit enter to go back to shell>")
            local index = Utils.indexOf(activeApps, runningApp)

            if index then
                table.remove(activeApps, index)
            end

            if activeApp == runningApp then
                showingAppList = true
                appListWindow.setVisible(true)
            end
        end)
    end
end

EventLoop.run(function()
    switchToAppSelection()
end, function()
    appSelection()
end, function()
    appStarter()
end)
