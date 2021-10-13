ChronOS = { }
ChronOS.Shell = { }

function ChronOS:run()
    MessagePump.init()
    Log.open()

    local appFiles = Disk.getFiles("/rom/classes/Apps")
    self._availableApps = { }

    for k, appFile in ipairs(appFiles) do
        local appName = string.gsub(appFile, "/rom/classes/Apps/", "")
        appName = string.gsub(appName, "%.lua", "")
        table.insert(self._availableApps, appName)
    end

    self._runningApps = { }
    self._runningApp = nil

    self._terminal = System.TerminalWrapper.new(term.current())

    MessagePump.on("key", function(key)
        if (key == keys.f10) then
            term.clear()
            term.setCursorPos(1, 1)
            MessagePump.quit()
        elseif (key == keys.f5) then
            self:reboot()
        elseif (key == keys.f4) then
            self:quitRunningApp()
        elseif (key == keys.f7) then
            -- todo: show previous app
        elseif (key == keys.f8) then
            -- todo: show next app
        end
    end )

    -- function no longer exists
--    MessagePump.beforeQuit( function()
--        Log.close()
--    end )

    --    self:runApp("AppList")
    self:runApp("Test")
    MessagePump.run()
end

function ChronOS:runApp(name)
    local runningApp = self:getRunningApp()

    if (runningApp ~= nil) then
        runningApp:getWindow():blur()
    end

    local tw = self:getTerminal()
    local win = UI.AppWindow.new(name)
    tw:setNode(win)

    local app = Apps[name].new(win)

    win:focus()
    tw:update()

    self._runningApp = app
    table.insert(self._runningApps, app)

    app:run()
end

--- <summary></summary>
--- <returns type="System.TerminalWrapper"></returns>
function ChronOS:getTerminal()
    return self._terminal
end

--- <summary></summary>
--- <returns type="table"></returns>
function ChronOS:getAvailableApps()
    return self._availableApps
end

--- <summary></summary>
--- <returns type="table"></returns>
function ChronOS:getRunningApps()
    return self._runningApps
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function ChronOS:getRunningApp()
    return self._runningApp
end

function ChronOS:quitRunningApp()
    local runningApp = self:getRunningApp()

    if (runningApp ~= nil) then
        runningApp:getWindow():blur()
        runningApp:quit()
    end

    local runningApps = self:getRunningApps()
    local index

    for i = 1, #runningApps do
        if (runningApps[i] == runningApp) then
            index = i
        end
    end

    table.remove(self._runningApps, index)

    if (#runningApps == 0) then
        self:reboot()
    else
        local tw = self:getTerminal()
        local previousApp = runningApps[#runningApps]
        local previousWin = previousApp:getWindow()
        previousWin:focus()
        tw:setNode(previousWin)
        tw:update()
        self._runningApp = previousApp
    end
end

function ChronOS:reboot()
    os.reboot()
end