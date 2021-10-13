local AppList = { }

--- <summary>
--- </summary>
--- <returns type="AppList"></returns>
function AppList.new(window)
    local instance = System.App.new(window)
    setmetatable(AppList, { __index = System.App })
    setmetatable(instance, { __index = AppList })
    instance:ctor()

    return instance
end

function AppList:ctor()
    local win = self:base():getWindow()
    
    local menu = UI.ListMenu.new()
    local availableApps = ChronOS:getAvailableApps()

    menu:addItem("I am a text with several words in it - i might not fit into a single line! Let's see how the UI.Label handles rendering of that.", function() end)
    for i = 1, #availableApps do
        menu:addItem(availableApps[i], function() end)
    end

    win:setContent(menu)
end

function AppList:run()

end

--- <summary></summary>
--- <returns type="Apps.AppList"></returns>
function AppList.cast(instance)
    return instance
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function AppList.super()
    return UI.Node
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function AppList:base()
    return self
end

if (Apps == nil) then Apps = { } end
Apps.AppList = AppList