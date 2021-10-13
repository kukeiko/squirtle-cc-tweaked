local Leaf = { }

--- <summary></summary>
--- <returns type="UI.Leaf"></returns>
function Leaf.new()
    local instance = UI.Node.new()
    setmetatable(Leaf, { __index = UI.Node })
    setmetatable(instance, { __index = Leaf })

    instance:ctor()

    return instance
end

function Leaf:ctor()
    self._buffer = { }
    self._minWidth = 0
    self._minHeight = 0
end

--- <summary></summary>
--- <returns type="UI.Leaf"></returns>
function Leaf.cast(Leaf)
    return Leaf
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Leaf.super()
    return UI.Node
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Leaf:base()
    return self
end

function Leaf:getBuffer()
    return self._buffer
end

function Leaf:resetBuffer(w, h)
    self._buffer = { }

    for y = 1, h do
        local line = { }
        table.insert(self._buffer, line)

        for x = 1, w do
            table.insert(line, "")
        end
    end
end

function Leaf:write(x, y, char)
    if (y > #self._buffer) then return nil end
    if (x > #self._buffer[y]) then return nil end

    self._buffer[y][x] = char
end

function Leaf:getMinWidth()
    if(self._minWidth == nil) then
        return self:getContentWidth()
    end

    return self._minWidth
end

function Leaf:setMinWidth(minWidth)
    self._minWidth = minWidth
end

function Leaf:getMinHeight()
    if(self._minHeight == nil) then
        return self:getContentHeight()
    end

    return self._minHeight
end

function Leaf:setMinHeight(minHeight)
    self._minHeight = minHeight
end

if (UI == nil) then UI = { } end
UI.Leaf = Leaf