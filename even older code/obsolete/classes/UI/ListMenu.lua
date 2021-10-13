local ListMenu = { }

--- <summary></summary>
--- <returns type="UI.ListMenu"></returns>
function ListMenu.new()
    local instance = UI.VStackBranch.new()
    setmetatable(ListMenu, { __index = UI.VStackBranch })
    setmetatable(instance, { __index = ListMenu })

    instance:ctor()

    return instance
end

function ListMenu:ctor()

end

function ListMenu:addItem(text, handler)
    local item = UI.ListMenuItem.new(text, handler)
    self:addChild(item)

    if (self:numItems() == 1) then
        item:isSelected(true)
    end
end

function ListMenu:getItems()
    return ListMenu.super().super().getChildren(self)
end

function ListMenu:getSelectedIndex()
    local items = self:getItems()

    for i = 1, #items do
        if (items[i]:isSelected()) then
            return i
        end
    end
end

function ListMenu:numItems()
    return #self:getItems()
end

function ListMenu:focus()
    UI.Node.focus(self)

    self:on("key", function(key)
        local items = self:getItems()
        local selectedIndex = self:getSelectedIndex()
        local newIndex = selectedIndex
        local doUpdate = true

        if (key == keys.up) then
            newIndex = newIndex - 1

            if (newIndex <= 0) then
                newIndex = #items
            end
        elseif (key == keys.down) then
            newIndex = newIndex + 1

            if (newIndex > #items) then
                newIndex = 1
            end
        elseif (key == keys.enter) then
            items[selectedIndex]:invoke()
        else
            doUpdate = false
        end

        if (newIndex ~= selectedIndex) then
            self:getItems()[selectedIndex]:isSelected(false)
            self:getItems()[newIndex]:isSelected(true)
        end

        if (doUpdate) then
            self:requireUpdate()
        end
    end )
end

--- <summary></summary>
--- <returns type="UI.ListMenu"></returns>
function ListMenu.cast(instance)
    return instance
end

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function ListMenu:base()
    return self
end

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function ListMenu.super()
    return UI.VStackBranch
end

-- todo: inherit from UI.Label to enable adding it as a child to ListMenu
local ListMenuItem = { }

--- <summary></summary>
--- <returns type="UI.ListMenuItem"></returns>
function ListMenuItem.new(text, handler)
    local instance = UI.Label.new(text, UI.Label.Align.Justify)
    setmetatable(ListMenuItem, { __index = UI.Label })
    setmetatable(instance, { __index = ListMenuItem })
    instance:ctor(handler)

    return instance
end

function ListMenuItem:ctor(handler)
    self._handler = handler
    self._isSelected = false
end

function ListMenuItem:getText()
    if (self:isSelected()) then
        return "> " .. ListMenuItem.super().getText(self)
    else
        return "  " .. ListMenuItem.super().getText(self)
    end
end

function ListMenuItem:setText(text)
    ListMenuItem.super().setText(self, text)
end

function ListMenuItem:isSelected(flag)
    if (flag ~= nil) then
        self._isSelected = flag
    end

    return self._isSelected
end

function ListMenuItem:getHandler()
    return self._handler
end

function ListMenuItem:invoke()
    self:getHandler()()
end

--- <summary></summary>
--- <returns type="UI.ListMenuItem"></returns>
function ListMenuItem.cast(instance)
    return instance
end

--- <summary></summary>
--- <returns type="UI.Label"></returns>
function ListMenuItem:base()
    return self
end

--- <summary></summary>
--- <returns type="UI.Label"></returns>
function ListMenuItem.super()
    return UI.Label
end

if (UI == nil) then UI = { } end
UI.ListMenu = ListMenu
UI.ListMenuItem = ListMenuItem