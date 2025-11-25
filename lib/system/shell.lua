if _ENV["Shell"] then
    return _ENV["Shell"] --[[@as ShellApplication]]
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"
local ApplicationApi = require "lib.system.application-api"
local ShellApplication = require "lib.system.shell-application"

local width, height = term.getSize()

---@class Shell
---@field window table
---@field root ShellApplication
---@field current ShellApplication
---@field applications ShellApplication[]
local Shell = {window = window.create(term.current(), 1, 1, width, height, false), applications = {}}

---@param shellApplication ShellApplication
local function switchToApplication(shellApplication)
    Shell.current.window.setVisible(false)

    if Shell.current.windows[Shell.current.windowIndex] then
        EventLoop.queue("shell-window:invisible", Shell.current.windows[Shell.current.windowIndex]:getId())
    end

    Shell.current = shellApplication
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
function Shell:isUiEvent(event)
    return isUiEvent(event)
end

---@param event string
function Shell:isShellWindowEvent(event)
    return isShellWindowEvent(event)
end

---@param shellApplication ShellApplication
---@return table
local function createApplicationEnvironment(shellApplication)
    return setmetatable({
        arg = {}, -- [todo] ❌ implement & pass along program arguments
        nextId = nextId, -- making sure to have globally unique ids
        Shell = shellApplication -- funnel Shell calls through the application instance instead
    }, {__index = _ENV})
end

local addThreadToMainLoop, runMainLoop = EventLoop.createRun()

---@param shellApplication ShellApplication
---@param run function
local function wrapRun(shellApplication, run)
    return function()
        EventLoop.configure({
            window = shellApplication.window,
            accept = function(event, ...)
                local args = {...}

                if isShellEvent(event, args[1]) then
                    return false
                elseif isUiEvent(event) then
                    return shellApplication == Shell.current
                end

                return true
            end
        })

        os.sleep(.1)

        local success, message = pcall(run)

        if not success then
            print(string.format("%s crashed", shellApplication.metadata.name))
            print(message)
            Utils.waitForUserToHitEnter("<hit enter to continue>")
        end
    end
end

---@param shellApplication ShellApplication
---@param fn function
local function bootstrap(shellApplication, fn)
    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(true)
    Shell.root = shellApplication
    Shell.current = shellApplication
    Shell.current.window.setVisible(true)

    addThreadToMainLoop(wrapRun(shellApplication, fn))

    EventLoop.waitForAny(function()
        runMainLoop()
    end, function()
        while true do
            -- on tab, goto root application
            EventLoop.pullKey(keys.tab)

            if Shell.current ~= Shell.root then
                switchToApplication(Shell.root)
            end
        end
    end)

    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(false)
end

---@param shellApplication ShellApplication
---@param fn function
function Shell:run(shellApplication, fn)
    if #Shell.applications == 0 then
        bootstrap(shellApplication, fn)
    else
        fn()
    end
end

---@param hostApplication ShellApplication
---@param path string
function Shell:launch(hostApplication, path)
    local alreadyRunning = Utils.find(Shell.applications, function(item)
        return item.metadata.path == path
    end)

    if alreadyRunning then
        switchToApplication(alreadyRunning)
        return
    end

    local metadata = ApplicationApi.getApplication(path, true)
    local appWindow = window.create(Shell.window, 1, 1, width, height, false)
    local shellApplication = ShellApplication.new(metadata, appWindow, Shell)

    if Shell.current == hostApplication then
        Shell.current.window.setVisible(false)
        Shell.current = shellApplication
        Shell.current.window.setVisible(true)
    end

    table.insert(Shell.applications, shellApplication)

    local fn = wrapRun(shellApplication, function()
        EventLoop.queue("shell:start")
        local fn, message = load(metadata.content, "@/" .. metadata.path, nil, createApplicationEnvironment(shellApplication))

        if not fn then
            error(message)
        end

        -- [todo] ❌ if "fn" crashes and user hits "enter" to continue, nothing happens. also, terminating doesn't work.
        -- need to understand & adapt wrapRun(), especially together its usage in bootstrap
        EventLoop.waitForAny(function()
            while true do
                local _, id = EventLoop.pull("shell:terminate")

                if id == shellApplication:getId() then
                    break
                end
            end
        end, fn)

        Utils.remove(Shell.applications, shellApplication)
        EventLoop.queue("shell:stop")

        if Shell.current == shellApplication then
            switchToApplication(hostApplication)
        end
    end)

    addThreadToMainLoop(fn)
end

---@param hostApplication ShellApplication
---@param path string
function Shell:terminate(hostApplication, path)
    local shellApplication = Utils.find(Shell.applications, function(item)
        return item.metadata.path == path
    end)

    if not shellApplication then
        return
    end

    EventLoop.queue("shell:terminate", shellApplication:getId())

    if Shell.current == shellApplication then
        switchToApplication(hostApplication)
    end
end

---@param path string
---@return boolean
function Shell:isRunning(path)
    return Utils.find(Shell.applications, function(item)
        return item.metadata.path == path
    end) ~= nil
end

function Shell:pullApplicationStateChange()
    EventLoop.waitForAny(function()
        EventLoop.pull("shell:start")
    end, function()
        EventLoop.pull("shell:stop")
    end)
end

---@type Application
local metadata = {name = fs.getName(arg[0]), path = arg[0], version = "N/A"}
local appWindow = window.create(Shell.window, 1, 1, width, height, false)

return ShellApplication.new(metadata, appWindow, Shell)
