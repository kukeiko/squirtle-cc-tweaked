local AppWindow = { }

--- <summary></summary>
--- <returns type="UI.AppWindow"></returns>
function AppWindow.new(parent)
    local instance = UI.Node.new(parent)
    setmetatable(AppWindow, { __index = UI.Node })
    setmetatable(instance, { __index = AppWindow })

    instance:ctor()

    return instance
end

function AppWindow:ctor()
    local label = UI.Text.new(self, "AppWindow")
    Log.debug(label:getValue())
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function AppWindow:base()
    return self
end

function AppWindow:getMinWidth()
    return 0
end

function AppWindow:getMinHeight()
    return 20
end

--function AppWindow:update()

--end

--if (UI == nil) then UI = { } end
--UI.AppWindow = AppWindow