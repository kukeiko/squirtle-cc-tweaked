local AppMenu = { }

--- <summary>
--- </summary>
--- <returns type="AppMenu"></returns>
function AppMenu.new(unit)
    local instance = { }
    setmetatable(instance, { __index = AppMenu })
    instance:ctor(unit)

    return instance
end

function AppMenu:ctor(unit)
    self._unit = Squirtle.Unit.as(unit)

    local availableApps = { }

    local appFiles = Disk.getFiles("/rom/apps")
    for k, appFile in ipairs(appFiles) do
        local appName = string.gsub(appFile, "/rom/apps/", "")
        appName = string.gsub(appName, "%.lua", "")
        table.insert(availableApps, appName)
    end

    if (turtle) then
        appFiles = Disk.getFiles("/rom/apps/turtle")
        for k, appFile in ipairs(appFiles) do
            local appName = string.gsub(appFile, "/rom/apps/turtle/", "")
            appName = string.gsub(appName, "%.lua", "")
            table.insert(availableApps, appName)
        end
    elseif (pocket) then
        appFiles = Disk.getFiles("/rom/apps/pocket")
        for k, appFile in ipairs(appFiles) do
            local appName = string.gsub(appFile, "/rom/apps/pocket/", "")
            appName = string.gsub(appName, "%.lua", "")
            table.insert(availableApps, appName)
        end
    else
        appFiles = Disk.getFiles("/rom/apps/computer")
        for k, appFile in ipairs(appFiles) do
            local appName = string.gsub(appFile, "/rom/apps/computer/", "")
            appName = string.gsub(appName, "%.lua", "")
            table.insert(availableApps, appName)
        end
    end

    table.sort(availableApps)

    self._appNames = availableApps
    self._list = availableApps
    self._searchText = ""
    self._selectedIndex = 1

    local w, h = term.getSize()
    self._window = window.create(term.current(), 1, 1, w, h)
end

function AppMenu:run()
    while (true) do
        self:draw()

        local key = MessagePump.pull("key")
        local keyName = keys.getName(key)
        local filterDirty = false

        if (key == keys.f4) then
            break
        elseif (key == keys.enter) then
            if (#self._list > 0) then
                local appName = self._list[self._selectedIndex]
                self._window.clear()
                self._window.setCursorPos(1, 1)
                self._window.setVisible(false)
                local buffer = Kevlar.Terminal.new()
                local app = Apps[appName].new(self._unit, buffer)
                local success, e = pcall( function() app:run() end)
                self._window.setVisible(true)

                if (not success) then
                    print(e)
                    print("")
                    print("<Press any key to continue>")
                    MessagePump.pull("key")
                end
            end
        elseif (key == keys.backspace) then
            local len = #self._searchText
            if (len ~= 0) then
                self._searchText = self._searchText:sub(1, len - 1)
                filterDirty = true
            end
        elseif (key == keys.up) then
            self._selectedIndex = self._selectedIndex - 1
            if (self._selectedIndex < 1) then
                if (#self._list == 0) then
                    self._selectedIndex = 1
                else
                    self._selectedIndex = #self._list
                end
            end
        elseif (key == keys.down) then
            self._selectedIndex = self._selectedIndex + 1
            if (self._selectedIndex > #self._list) then
                self._selectedIndex = 1
            end
        elseif (key == keys.space) then
            self._searchText = self._searchText .. " "
            filterDirty = true
        elseif (keyName:match("^%a$")) then
            self._searchText = self._searchText .. keyName
            filterDirty = true
            self._selectedIndex = 1
        end

        if (filterDirty) then
            self:filter()
        end
    end

    self._window.clear()
    self._window.setCursorPos(1, 1)
end

function AppMenu:filter()
    local filtered = { }
    local search = self._searchText
    local unfiltered = self._appNames

    if (#self._searchText == 0) then
        self._list = unfiltered
        return
    end

    for i = 1, #unfiltered do
        local appName = unfiltered[i]

        if (appName:lower():match(search)) then
            table.insert(filtered, appName)
        end
    end

    table.sort(filtered)
    self._list = filtered
end

function AppMenu:draw()
    local win = self._window
    local w, h = win.getSize()

    win.clear()
    win.setCursorPos(1, 1)
    win.clearLine()

    if (#self._searchText > 0) then
        win.write(self._searchText)
    else
        win.write("<enter keywords to filter>")
    end

    for i = 1, w do
        win.setCursorPos(i, 2)
        win.write("-")
    end

    --    local menuWin = window.create(win, 1, 3, w, h - 3)
    --    local menu = UI.ListMenu.new(menuWin)
    --    menu:addItem("Hello!")
    --    menu:addItem("Foo")
    --    menu:addItem("Bar")
    --    menu:addItem("Baz")
    --    menu:draw()
    local listHeight = h - 2
    local list = self._list

    for i = 1, listHeight do
        if (not list[i]) then
            break
        end

        win.setCursorPos(1, i + 2)
        if (self._selectedIndex == i) then
            win.write(">" .. list[i])
        else
            win.write(" " .. list[i])
        end
    end
end

if (Apps == nil) then Apps = { } end
Apps.AppMenu = AppMenu