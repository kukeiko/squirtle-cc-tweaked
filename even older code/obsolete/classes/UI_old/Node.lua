local Node = { }

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node.new(parent)
    local instance = { }
    setmetatable(instance, { __index = Node })

    instance:ctor(parent)

    return instance
end

function Node:ctor(parent)
    parent = UI.Node.cast(parent)
    self._parent = parent
    self._children = { }
    self._isVisible = true
    self._scroll = 0

    if (self._parent == nil) then
        local t = term.current()
        local w, h = t.getSize()
        self._window = window.create(t, 1, 1, w, h)
    else
        self._window = parent:attachChild(self)
    end
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node.cast(node)
    return node
end

function Node:attachChild(child)
    child = UI.Node.cast(child)
    local win = window.create(self:getWindow(), 1, 1, 0, 0)
    table.insert(self._children, child)

    return win
end

function Node:getChildren()
    return self._children
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node:getChild(index)
    return self._children[index]
end

function Node:numChildren()
    return #self._children
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Node:getParent()
    return self._parent
end

function Node:getWindow()
    return self._window
end

function Node:isVisible()
    return self._isVisible
end

function Node:show()
    self._isVisible = true
    self:getWindow():setVisible(true)
end

function Node:hide()
    self._isVisible = false
    self:getWindow():setVisible(false)
end

function Node:getMinSizes()
    return self:getMinWidth(), self:getMinHeight()
end

function Node:getMinWidth()
    return 0
end

function Node:getMinHeight()
    return 0
end

function Node:update()
    -- intellisense bug workaround
    local child = UI.Node.cast(nil)
--    local win = self:getWindow()
--    local winW, winH = window.getSize()
--    local line = 1

--    win.clear()
    
    for i = 1, #self._children do
        child = self._children[i]
        child:update()    

--        if (child:isVisible()) then
--            local minW, minH = child:getMinSizes()
--            local childWin = child:getWindow()

--            childWin.reposition(1, line, winW, minH)
--            Log.debug(1, line, winW, minH)
--            child:update()

--            line = line + minH
--        end
    end
end

--if (UI == nil) then UI = { } end
--UI.Node = Node