local Node = { }

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node.new()
    local instance = { }
    setmetatable(instance, { __index = Node })

    instance:ctor()

    return instance
end

function Node:ctor()
    self._width = 1
    self._height = 1
    self._widthSizeMode = Node.SizeMode.Stretch
    self._heightSizeMode = Node.SizeMode.Fit
    self._parent = nil
    self._isVisible = true
    self._eventListenerIds = { }
    self._isFocussed = false
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node.cast(node)
    return node
end

function Node:setParent(parent)
    self._parent = parent
end

function Node:requireUpdate()
    local parent = self:getParent()

    if (parent) then
        parent:requireUpdate()
    end
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node:getParent()
    return self._parent
end

function Node:hide()
    self._isVisible = false
end

function Node:show()
    self._isVisible = true
end

function Node:isVisible()
    return self._isVisible
end

function Node:update()
    error("Call to abstract method: Node:update()")
end

function Node:getBuffer()
    error("Call to abstract method: Node:getBuffer()")
end

function Node:getSize()
    return self:getWidth(), self:getHeight()
end

function Node:setSize(w, h)
    self:setWidth(w)
    self:setHeight(h)
end

function Node:getWidth()
    return self._width
end

function Node:setWidth(w)
    self._width = w
end

function Node:getMinWidth()
    error("Call to abstract method: Node:getMinWidth()")
end

function Node:getHeight()
    return self._height
end

function Node:setHeight(h)
    self._height = h
end

function Node:getMinHeight()
    error("Call to abstract method: Node:getMinHeight()")
end

function Node:getContentWidth()
    error("Call to abstract method: Node:getContentWidth()")
end

function Node:getContentHeight()
    error("Call to abstract method: Node:getContentWidth()")
end

function Node:getWidthSizeMode()
    return self._widthSizeMode
end

function Node:setWidthSizeMode(mode)
    self._widthSizeMode = mode
end

function Node:getHeightSizeMode()
    return self._heightSizeMode
end

function Node:setHeightSizeMode(mode)
    self._heightSizeMode = mode
end

function Node:getSizeModes()
    return self:getWidthSizeMode(), self:getHeightSizeMode()
end

function Node:focus()
    self._isFocussed = true
end

function Node:isFocussed()
    return self._isFocussed
end

function Node:blur()
    for i = 1, #self._eventListenerIds do
        MessagePump.off(self._eventListenerIds[i])
    end

    self._isFocussed = false
end

function Node:on(event, handler)
    table.insert(self._eventListenerIds, MessagePump.on(event, handler))
end

Node.SizeMode = {
    Fit = 0,
    Stretch = 1
}

if (UI == nil) then UI = { } end
UI.Node = Node