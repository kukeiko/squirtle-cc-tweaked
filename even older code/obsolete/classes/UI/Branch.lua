local Branch = { }

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function Branch.new()
    local instance = UI.Node.new()
    setmetatable(Branch, { __index = UI.Node })
    setmetatable(instance, { __index = Branch })

    instance:ctor()

    return instance
end

function Branch:ctor()
    self._buffer = { }
    self._children = { }
end

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function Branch.cast(instance)
    return instance
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Branch.super()
    return UI.Node
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Branch:base()
    return self
end


function Branch:update()
    local children = self:base():getChildren()

    for i = 1, #children do
        children[i]:update()
    end
end

function Branch:addChild(child)
    table.insert(self._children, child)
    child:setParent(self)
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Branch:getChild(index)
    return self:getChildren()[index]
end

function Branch:getChildren()
    return self._children
end

function Branch:numChildren()
    return #self:getChildren()
end

function Branch:removeChild(child)
    local index = self:indexOf(child)

    if (index) then
        table.remove(self._children, index)
    end
end

function Branch:indexOf(child)
    for i = 1, self:numChildren() do
        if (self:getChild(i) == child) then
            return i
        end
    end
end

function Branch:indexOfFocussed()
    for i = 1, self:numChildren() do
        if (self:getChild(i):isFocussed()) then
            return i
        end
    end
end

function Branch:getContentWidth()
    -- todo: implement
end

function Branch:getContentHeight()
    -- todo: implement
end

function Branch:focus()
    local child = self:getChild(1)

    if(child) then
        child:focus()
    end
end

function Branch:blur()
    UI.Node.blur(self)

    local index = self:indexOfFocussed()

    if (index ~= nil) then
        self:getChild(index):blur()
    end
end

if (UI == nil) then UI = { } end
UI.Branch = Branch