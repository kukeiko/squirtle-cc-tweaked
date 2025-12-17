if _ENV["Shell"] then
    return _ENV["Shell"] --[[@as Shell]]
end

local version = require "version"
local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"
local PeripheralApi = require "lib.common.peripheral-api"
local ApplicationApi = require "lib.system.application-api"
local ShellApplication = require "lib.system.shell-application"
local ShellService = require "lib.system.shell-service"
local appsWindow = require "lib.system.windows.apps-window"
local updateAppsWindow = require "lib.system.windows.update-apps-window"
local installAppsWindow = require "lib.system.windows.install-apps-window"
local logsWindow = require "lib.system.windows.logs-window"

local settingsPath = ".kita/settings.json"

---@class ShellSettings
---@field autorun string[]

---@return ShellSettings
local function loadSettings()
    ---@type ShellSettings
    local settings = Utils.readJson(settingsPath) or {}
    settings.autorun = settings.autorun or {}

    return settings
end

local width, height = term.getSize()

---@class Shell
---@field window table
---@field root ShellApplication
---@field current ShellApplication
---@field applications ShellApplication[]
---@field settings ShellSettings
---@field remoteOptions table<string, EditEntity>
local Shell = {
    window = window.create(term.current(), 1, 1, width, height, false),
    applications = {},
    settings = loadSettings(),
    remoteOptions = {}
}

---@param name string
---@return ShellApplication?
local function findApplicationByName(name)
    return Utils.find(Shell.applications, function(item)
        return item.metadata.name == name
    end)
end

---@param application ShellApplication
local function switchToApplication(application)
    Shell.current.window.setVisible(false)

    if Shell.current.windows[Shell.current.windowIndex] then
        EventLoop.queue("shell-window:invisible", Shell.current.windows[Shell.current.windowIndex]:getId())
    end

    Shell.current = application
    Shell.current.window.setVisible(true)

    if Shell.current.windows[Shell.current.windowIndex] then
        EventLoop.queue("shell-window:visible", Shell.current.windows[Shell.current.windowIndex]:getId())
    end
end

---@param event string
---@param value any
local function isShellEvent(event, value)
    if event == "key_up" and value == keys.tab then
        return true
    end
end

---@param event string
---@return boolean
local function isUiEvent(event)
    return event == "char" or event == "key" or event == "key_up" or event == "paste"
end

---@param event string
local function isShellWindowEvent(event)
    return Utils.startsWith(event, "shell-window")
end

---@param event string
function Shell.isUiEvent(event)
    return isUiEvent(event)
end

---@param event string
function Shell.isShellWindowEvent(event)
    return isShellWindowEvent(event)
end

---@param shellApplication ShellApplication
---@return table
local function createApplicationEnvironment(shellApplication)
    return setmetatable({
        arg = {[0] = shellApplication:getPath()}, -- [todo] ❌ implement & pass along program arguments
        nextId = nextId, -- making sure to have globally unique ids
        Shell = Shell -- share Shell instance with bundle apps
    }, {__index = _ENV})
end

local function createWindow()
    return window.create(Shell.window, 1, 1, width, height, false)
end

---@return ShellApplication
local function createShellUi()
    ---@type Application
    local metadata = {name = "shell", path = "null", version = version()}
    local application = ShellApplication.new(metadata, createWindow(), Shell)
    application:addWindow("Apps", appsWindow)
    application:addWindow("Update", updateAppsWindow)
    application:addWindow("Install", installAppsWindow)
    application:addWindow("Logs", logsWindow)

    if PeripheralApi.findWirelessModem() then
        application:addWindow("Shell Service", function()
            ShellService.run(Shell)
        end)
    end

    return application
end

local addThread, runMainLoop = EventLoop.createRun()

---@param application ShellApplication
---@param run function
---@param switchBackTo? ShellApplication
local function wrapRunApplication(application, run, switchBackTo)
    return function()
        EventLoop.queue("shell:app-start")
        EventLoop.configure({
            window = application.window,
            accept = function(event, ...)
                local args = {...}

                if isShellEvent(event, args[1]) then
                    return false
                elseif isUiEvent(event) then
                    return application == Shell.current
                end

                return true
            end
        })

        EventLoop.waitForAny(function()
            while true do
                local _, id = EventLoop.pull("shell:terminate")

                if id == application:getId() then
                    break
                end
            end
        end, function()
            local success, message = pcall(run)

            if not success then
                print(string.format("%s crashed", application.metadata.name))
                print(message)
                Utils.waitForUserToHitEnter("<hit enter to continue>")
            end
        end)

        Utils.remove(Shell.applications, application)
        Shell.remoteOptions[application.metadata.name] = nil
        EventLoop.queue("shell:app-stop")

        if Shell.current == application then
            if switchBackTo then
                switchToApplication(switchBackTo)
            elseif Shell.root and Shell.root ~= application then
                switchToApplication(Shell.root)
            elseif #Shell.applications > 0 then
                switchToApplication(Shell.applications[1])
            end
        end
    end
end

---@param name string
---@param isAutorun? boolean
---@return ShellApplication, function
local function loadApplication(name, isAutorun)
    local root = Utils.isDev() and "app" or ".kita/app"
    local platformFolder = fs.combine(root, Utils.getPlatform())
    local apps = ApplicationApi.readApps(platformFolder, {name}, true, Utils.isDev() and version() or nil)
    local metadata = apps[1]

    if not metadata then
        error(string.format("%s app %s not found", Utils.getPlatform(), name))
    end

    local application = ShellApplication.new(metadata, createWindow(), Shell, isAutorun)

    local loadAndRun = function()
        local fn, message = load(metadata.content, "@/" .. application:getPath(), nil, createApplicationEnvironment(application))

        if fn then
            fn()
        else
            error(message)
        end
    end

    return application, loadAndRun
end

---@param applications ShellApplication[]
---@param root? ShellApplication
---@param shown? ShellApplication
local function bootstrap(applications, root, shown)
    if #applications == 0 then
        error("applications was empty")
    end

    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(true)
    Shell.root = root or applications[1]

    for _, application in ipairs(applications) do
        if not Shell.isRunning(application.metadata.name) then
            table.insert(Shell.applications, application)
            addThread(wrapRunApplication(application, application:getRunFunction()))
        end
    end

    for _, name in ipairs(Shell.settings.autorun) do
        if not Shell.isRunning(name) then
            local application, fn = loadApplication(name, true)
            table.insert(Shell.applications, application)
            addThread(wrapRunApplication(application, fn))
        end
    end

    Shell.current = shown or Shell.root
    Shell.current.window.setVisible(true)

    EventLoop.waitForAny(function()
        runMainLoop()
    end, function()
        while true do
            -- switch to root application
            EventLoop.pullKey(keys.tab)

            if Shell.current ~= Shell.root then
                switchToApplication(Shell.root)
            end
        end
    end, function()
        while true do
            EventLoop.pullKey(keys.f3)
            local metadata = Utils.map(Shell.applications, function(item)
                ---@type Application
                local withoutContent = {name = item.metadata.name, path = item:getPath(), version = item.metadata.version}
                return withoutContent
            end)
            Utils.writeJson(string.format("shell-applications-%s.json", os.epoch("utc")), metadata)
        end
    end)

    Shell.applications = {}
    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(false)
end

---@param arg string[]
---@return ShellApplication
function Shell.getApplication(arg)
    local path = arg[0]
    local application = Utils.find(Shell.applications, function(candidate)
        return candidate:getPath() == path
    end)

    if not application then
        ---@type Application
        local metadata = {name = fs.getName(path), path = path, version = version()}
        application = ShellApplication.new(metadata, createWindow(), Shell)
    end

    return application
end

---@param skipKita? boolean
---@return Application[]
function Shell.getInstalled(skipKita)
    local root = Utils.isDev() and "app" or ".kita/app"
    local platformFolder = fs.combine(root, Utils.getPlatform())
    local apps = ApplicationApi.readApps(platformFolder, nil, nil, Utils.isDev() and version() or nil)

    if skipKita then
        apps = Utils.filter(apps, function(item)
            return item.name ~= "kita"
        end)
    end

    return apps
end

---@param name string
---@return boolean
function Shell.isInstalled(name)
    local root = Utils.isDev() and "app" or ".kita/app"
    local platformFolder = fs.combine(root, Utils.getPlatform())
    local apps = ApplicationApi.readApps(platformFolder, {name}, true, Utils.isDev() and version() or nil)

    return apps[1] ~= nil
end

---@param name string
---@param applicationService ApplicationService|RpcClient
function Shell.install(name, applicationService)
    if Utils.isDev() then
        return
    end

    local app = applicationService.getApplication(Utils.getPlatform(), name, true)
    ApplicationApi.writeApp(fs.combine(".kita/app", Utils.getPlatform()), app)
    EventLoop.queue("shell:app-installed")
end

---@param application ShellApplication
---@param withShellUi? boolean
function Shell.run(application, withShellUi)
    if #Shell.applications == 0 and withShellUi then
        local shellApplication = createShellUi()
        bootstrap({shellApplication, application}, shellApplication, application)
    elseif #Shell.applications == 0 then
        bootstrap({application})
    else
        application:getRunFunction()()
    end
end

---@param name string
---@param host? ShellApplication
function Shell.launch(name, host)
    local alreadyRunning = findApplicationByName(name)

    if alreadyRunning then
        switchToApplication(alreadyRunning)
        return
    end

    local application, fn = loadApplication(name)
    table.insert(Shell.applications, application)
    addThread(wrapRunApplication(application, fn, host))

    if host and Shell.current == host then
        switchToApplication(application)
    end
end

---@param name string
function Shell.show(name)
    local application = findApplicationByName(name)

    if not application then
        return
    end

    switchToApplication(application)
end

---@param hostApplication ShellApplication
---@param name string
function Shell.terminate(hostApplication, name)
    local application = findApplicationByName(name)

    if not application then
        return
    end

    EventLoop.queue("shell:terminate", application:getId())

    if Shell.current == application then
        switchToApplication(hostApplication)
    end
end

---@param name string
---@return boolean
function Shell.isRunning(name)
    return findApplicationByName(name) ~= nil
end

function Shell.pullApplicationStateChange()
    EventLoop.waitForAny(function()
        EventLoop.pull("shell:app-start")
    end, function()
        EventLoop.pull("shell:app-stop")
    end)
end

---@param name string
function Shell.addAutorun(name)
    if Utils.contains(Shell.settings.autorun, name) then
        return
    end

    table.insert(Shell.settings.autorun, name)

    if not Utils.isDev() then
        Utils.writeJson(settingsPath, Shell.settings)

        if not fs.exists("startup") then
            if fs.getName(arg[0]) == "kita" then
                Utils.writeStartupFile(string.format("%s %s", arg[0], table.concat(Shell.settings.autorun, " ")))
            else
                Utils.writeStartupFile(arg[0])
            end
        end
    end
end

---@param name string
function Shell.removeAutorun(name)
    Shell.settings.autorun = Utils.filter(Shell.settings.autorun, function(item)
        return item ~= name
    end)

    if not Utils.isDev() then
        Utils.writeJson(settingsPath, Shell.settings)

        if #Shell.settings.autorun == 0 then
            Utils.deleteStartupFile()
        end
    end
end

---@param name string
---@param editEntity EditEntity
function Shell.exposeRemoteOptions(name, editEntity)
    Shell.remoteOptions[name] = editEntity
end

return Shell
