if _ENV["Shell"] then
    return _ENV["Shell"] --[[@as ShellApplication]]
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"
local ApplicationApi = require "lib.apis.application-api"
local ShellApplication = require "lib.ui.shell-application"

local width, height = term.getSize()

---@class Shell
---@field window table
---@field root ShellApplication
---@field current ShellApplication
---@field applications ShellApplication[]
---@field isRunning boolean
---@field addThreadToMainLoop fun(...: function)
local Shell = {window = window.create(term.current(), 1, 1, width, height, false), applications = {}, isRunning = false}

local function drawMenu()
    local index = Shell.current.windowIndex
    local left = index > 1 and string.format("< %s", Shell.current.windows[index - 1].title) or nil
    local right = index < #Shell.current.windows and string.format("%s >", Shell.current.windows[index + 1].title) or nil
    local width, height = Shell.window.getSize()
    Shell.window.setCursorPos(1, height - 1)
    Shell.window.write(string.rep("-", width))
    Shell.window.setCursorPos(1, height)
    Shell.window.clearLine()

    if left then
        Shell.window.setCursorPos(1, height)
        Shell.window.write(left)
    end

    if right then
        Shell.window.setCursorPos(width - #right, height)
        Shell.window.write(right)
    end
end

---@param shellApplication ShellApplication
local function switchToApplication(shellApplication)
    Shell.current.window.setVisible(false)
    EventLoop.queue("shell-window:invisible", Shell.current.windows[Shell.current.windowIndex]:getId())
    Shell.current = shellApplication
    Shell.current.window.setVisible(true)
    EventLoop.queue("shell-window:visible", Shell.current.windows[Shell.current.windowIndex]:getId())
    drawMenu()
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

---@param application ShellApplication
---@param window ShellWindow
---@return boolean
local function isActiveApplicationWindow(application, window)
    return Shell.current == application and Shell.current.windows[Shell.current.windowIndex] == window
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

---@param application ShellApplication
---@param shellWindow ShellWindow
---@return function
local function createWindowFunction(application, shellWindow)
    return function()
        EventLoop.configure({
            window = shellWindow.window, -- redirects term to this
            accept = function(event, ...) -- predicate for passing through events
                local args = {...}

                if isShellEvent(event, args[1]) then
                    return false
                elseif isUiEvent(event) then
                    return isActiveApplicationWindow(application, shellWindow)
                elseif isShellWindowEvent(event) then
                    return args[1] == shellWindow:getId()
                end

                return true
            end
        })

        os.sleep(.1)

        if isActiveApplicationWindow(application, shellWindow) then
            EventLoop.queue("shell-window:visible", shellWindow:getId())
        end

        shellWindow.fn(shellWindow)

        -- [note] this hack is needed in case the UI event was responsible for terminating the window,
        -- at which point the next window is the active one and also receives the UI event (i.e. it "bleeds" over)
        os.sleep(.1)
        shellWindow.window.clear()
        application:removeWindow(shellWindow)

        if #application.windows == 0 then
            -- end the application
            local applicationIndex = Utils.indexOf(Shell.applications, Shell.current) --[[@as integer]]
            table.remove(Shell.applications, applicationIndex)

            -- if an app other than root was ended, show root app
            if application == Shell.current and Shell.current ~= Shell.root then
                switchToApplication(Shell.root)
            end
        end
    end
end

local function run()
    if Shell.isRunning then
        return
    end

    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(true)

    local initialWindowFunctions = Utils.map(Shell.root.windows, function(shellWindow)
        return createWindowFunction(Shell.root, shellWindow)
    end)

    local addThreadToMainLoop, run = EventLoop.createRun(table.unpack(initialWindowFunctions))
    Shell.addThreadToMainLoop = addThreadToMainLoop
    Shell.isRunning = true

    if Shell.root.windows[1] then
        Shell.root.windowIndex = 1
        Shell.root.window.setVisible(true)
        Shell.root.windows[1]:setVisible(true)
    end

    EventLoop.waitForAny(function()
        run()
    end, function()
        while true do
            -- on tab, goto root application
            EventLoop.pullKey(keys.tab)

            if Shell.current ~= Shell.root then
                switchToApplication(Shell.root)
            end
        end
    end, function()
        drawMenu()

        while true do
            local key = EventLoop.pullKeys({keys.left, keys.right})
            local nextIndex = Shell.current.windowIndex

            if key == keys.left then
                nextIndex = math.max(1, nextIndex - 1)
            else
                nextIndex = math.min(#Shell.current.windows, nextIndex + 1)
            end

            if nextIndex ~= Shell.current.windowIndex then
                Shell.current:switchToWindowIndex(nextIndex)
            end
        end
    end)

    Shell.isRunning = false
    Shell.window.clear()
    Shell.window.setCursorPos(1, 1)
    Shell.window.setVisible(false)
end

---@param hostApplication ShellApplication
---@param path string
local function launchApp(hostApplication, path)
    local alreadyRunning = Utils.find(Shell.applications, function(item)
        return item.metadata.path == path
    end)

    if alreadyRunning then
        switchToApplication(alreadyRunning)
        return
    end

    local metadata = ApplicationApi.getApplication(path, true)
    local appWindow = window.create(Shell.window, 1, 1, width, height - 2, false)
    -- [todo] ❌ run() should be blocking, just like run() for the root app does
    local shellApplication = ShellApplication.new(metadata, appWindow, run)
    shellApplication.launchApp = function(path)
        launchApp(shellApplication, path)
    end

    shellApplication.addWindowToShell = function(shellWindow)
        Shell.addThreadToMainLoop(createWindowFunction(shellApplication, shellWindow))
    end

    shellApplication.drawMenu = function()
        if Shell.current == shellApplication then
            drawMenu()
        end
    end

    table.insert(Shell.applications, shellApplication)

    if Shell.current == hostApplication then
        Shell.current.window.setVisible(false)
        Shell.current = shellApplication
        Shell.current.window.setVisible(true)
    end

    Shell.addThreadToMainLoop(function()
        -- [todo] ❌ add accept handling
        EventLoop.configure({window = appWindow})
        -- [todo] ❓ can we just move this into EventLoop.configure()?
        os.sleep(.1)

        local fn, message = load(metadata.content, "@/" .. metadata.path, nil, createApplicationEnvironment(shellApplication))

        if not fn then
            print("error", message)
            Utils.waitForUserToHitEnter("<hit enter to continue>")
        else
            -- [todo] ❌ think about what happens to added windows, how to clean up app, etc.
            -- [todo] ❌ during the fn call, windows get added immediately to the main loop. that causes a difference in behavior between running the app directly
            -- vs. running it via launch(). I want the same behavior: add the windows to main loop once the app has called Shell:run()
            local success, message = pcall(fn)

            if shellApplication.windows[shellApplication.windowIndex] then
                -- [todo] ❌ hack
                shellApplication.windows[shellApplication.windowIndex]:setVisible(true)
            end

            drawMenu()

            if not success then
                print(message)
                Utils.waitForUserToHitEnter("<hit enter to continue>")
            end
        end
    end)
end

---@type Application
local metadata = {name = "foo", path = "bar/foo", version = "xyz"} -- [todo] replace with arg[0]
local appWindow = window.create(Shell.window, 1, 1, width, height - 2, false)
local app = ShellApplication.new(metadata, appWindow, run)

app.launchApp = function(path)
    launchApp(app, path)
end

app.addWindowToShell = function(shellWindow)
    if Shell.isRunning then
        Shell.addThreadToMainLoop(createWindowFunction(Shell.root, shellWindow))
    end
end

app.drawMenu = function()
    if Shell.current == app then
        drawMenu()
    end
end

Shell.root = app
Shell.current = app

return app
