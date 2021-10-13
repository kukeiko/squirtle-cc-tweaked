local ListMenu = { }

--- <summary></summary>
--- <returns type="UI.ListMenu"></returns>
function ListMenu.new(parent)
    local instance = UI.Node.new(parent)
    setmetatable(ListMenu, { __index = UI.Node })
    setmetatable(instance, { __index = ListMenu })

    instance:ctor()

    return instance
end

function ListMenu:ctor()
    self._items = { }
    self._index = 1
    self._keyListenerId = nil
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function ListMenu:base()
    return self
end

function ListMenu:getMinWidth()
    return 0
end

function ListMenu:getMinHeight()
    return #self._items
end

function ListMenu:addItem(text, handler)
    table.insert(self._items, { text = text, handler = handler })
end

function ListMenu:getIndex()
    return self._index
end

function ListMenu:decreaseIndex()
    self._index = self._index - 1

    if (self._index < 1) then
        self._index = #self._items
    end
end

function ListMenu:increaseIndex()
    self._index = self._index + 1

    if (self._index > #self._items) then
        self._index = 1
    end
end

function ListMenu:update()
    local window = self:base():getWindow()

    for i = 1, #self._items do
        local item = self._items[i]

        window.setCursorPos(1, i)

        if (i == self:getIndex()) then
            window.write("> " .. item.text)
        else
            window.write("  " .. item.text)
        end
    end
end

function ListMenu:focus()
    self._keyListenerId = MessagePump.on("key", function(key)
        local keyName = keys.getName(key)
        local dirty = false

        if (keyName == "down") then
            self:increaseIndex()
            dirty = true
        elseif (keyName == "up") then
            self:decreaseIndex()
            dirty = true
        end

        if (dirty) then
            self:update()
        end
    end )
end

function ListMenu:blur()
    if (self._keyListenerId) then
        MessagePump.off(self._keyListenerId)
    end
end

--if (UI == nil) then UI = { } end
--UI.ListMenu = ListMenu