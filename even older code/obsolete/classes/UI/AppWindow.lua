local AppWindow = { }

--- <summary></summary>
--- <returns type="UI.AppWindow"></returns>
function AppWindow.new(title)
    local instance = UI.VStackBranch.new()
    setmetatable(AppWindow, { __index = UI.VStackBranch })
    setmetatable(instance, { __index = AppWindow })

    instance:ctor(title)

    return instance
end

function AppWindow:ctor(title)
    self._titleLabel = UI.Label.new(title, UI.Label.Align.Center)
    self:addChild(self._titleLabel)

    self._headerLine = UI.HLine.new("-")
    self:addChild(self._headerLine)

    self._content = nil
end

--- <summary></summary>
--- <returns type="UI.AppWindow"></returns>
function AppWindow.cast(AppWindow)
    return AppWindow
end

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function AppWindow.super()
    return UI.VStackBranch
end

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function AppWindow:base()
    return self
end

function AppWindow:hideHeader()
    self._titleLabel:hide()
    self._headerLine:hide()
end

function AppWindow:showHeader()
    self._titleLabel:show()
    self._headerLine:show()
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function AppWindow:getContent()
    return self._content
end

function AppWindow:setContent(content)
    if (self:getContent() ~= nil) then
        self:removeChild(self:getContent())
    end

    self._content = content
    self:addChild(content)
end

function AppWindow:focus()
    AppWindow.super().focus(self)
    self:getContent():focus()
end

function AppWindow:blur()
    AppWindow.super().blur(self)
    self:getContent():blur()
end

if (UI == nil) then UI = { } end
UI.AppWindow = AppWindow