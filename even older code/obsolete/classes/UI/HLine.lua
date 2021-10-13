local HLine = { }

--- <summary></summary>
--- <returns type="UI.HLine"></returns>
function HLine.new(char)
    local instance = UI.Leaf.new()
    setmetatable(HLine, { __index = UI.Leaf })
    setmetatable(instance, { __index = HLine })

    char = char or "-"

    instance:ctor(char)

    return instance
end

function HLine:ctor(char)
    self._char = char
end

--- <summary></summary>
--- <returns type="UI.HLine"></returns>
function HLine.cast(HLine)
    return HLine
end

--- <summary></summary>
--- <returns type="UI.Leaf"></returns>
function HLine:base()
    return self
end

function HLine:update()
    local w = self:getWidth()
    local h = self:getHeight()

    self:base():resetBuffer(w, h)

    local char = self:getChar()

    for i = 1, w do
        self:base():write(i, 1, char)
    end
end

function HLine:getMinWidth()
    return 1
end

function HLine:getMinHeight()
    return 1
end

function HLine:getContentWidth()
    return 1
end

function HLine:getContentHeight()
    return 1
end

function HLine:getChar()
    return self._char
end

if (UI == nil) then UI = { } end
UI.HLine = HLine