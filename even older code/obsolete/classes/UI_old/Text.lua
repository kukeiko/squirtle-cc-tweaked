local Text = { }

--- <summary></summary>
--- <returns type="UI.Text"></returns>
function Text.new(parent, value, defaultValue)
    local instance = UI.Node.new(parent)
    setmetatable(Text, { __index = UI.Node })
    setmetatable(instance, { __index = Text })

    instance:ctor(value, defaultValue)

    return instance
end

function Text:ctor(value, defaultValue)
    self._value = value
    self._align = Text.Align.Left
    self._defaultValue = defaultValue or ""
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Text:base()
    return self
end

function Text:getMinWidth()
    return #self:getValue()
end

function Text:getMinHeight()
    return 1
end

--- <summary>getValue() may return the default value - this one doesn't</summary>
--- <returns type="string"></returns>
function Text:getRawValue()
    return self._value
end

--- <summary></summary>
--- <returns type="string"></returns>
function Text:getValue()
    if (self._value == nil) then
        return self:getDefaultValue()
    end

    return self._value
end

function Text:setValue(value)
    self._value = value
end

--- <summary></summary>
--- <returns type="string"></returns>
function Text:getDefaultValue()
    return self._defaultValue
end

function Text:setDefaultValue(value)
    self._defaultValue = value
end

--- <summary></summary>
--- <returns type="number"></returns>
function Text:getLength()
    return #self:getValue()
end

function Text:setAlign(align)
    self._align = align
end

function Text:getAlign()
    return self._align
end

function Text:update()
    local x
    local window = self:base():getWindow()
    local w, h = window.getSize()
    local align = self:getAlign()
    local length = self:getLength()

    if (align == Text.Align.Left) then
        x = 1
    elseif (align == Text.Align.Center) then
        x = math.floor((w / 2) -(length / 2)) + 1
    elseif (align == Text.Align.Right) then
        x =(w - length) + 1

        if (x < 1) then
            x = 1
        end
    end

    window.setCursorPos(x, 1)
    window.write(self:getValue())
end

Text.Align = {
    Left = 0,
    Center = 1,
    Right = 2
}

--if (UI == nil) then UI = { } end
--UI.Text = Text