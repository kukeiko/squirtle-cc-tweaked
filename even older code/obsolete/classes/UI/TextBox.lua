local TextBox = { }

--- <summary></summary>
--- <returns type="UI.TextBox"></returns>
function TextBox.new(defaultText, align)
    local instance = UI.Leaf.new()
    setmetatable(TextBox, { __index = UI.Leaf })
    setmetatable(instance, { __index = TextBox })

    defaultText = defaultText or ""
    align = align or TextBox.Align.Left

    instance:ctor(defaultText, align)

    return instance
end

function TextBox:ctor(defaultText, align)
    self._text = ""
    self._defaultText = defaultText
    self._align = align
end

--- <summary></summary>
--- <returns type="UI.TextBox"></returns>
function TextBox.cast(TextBox)
    return TextBox
end

--- <summary></summary>
--- <returns type="UI.Leaf"></returns>
function TextBox:base()
    return self
end

function TextBox:focus()
    self:on("key", function(key)
        local name = keys.getName(key)
        local doUpdate = true
        
        if (key == keys.backspace) then
            local len = #self:getText()

            if (len ~= 0) then
                self:setText(self:getText():sub(1, len - 1))
            end
        elseif (key == keys.space) then
            self:setText(self:getText() .. " ")
        elseif (name:match("^%a$")) then
            self:setText(self:getText() .. name)
        else
            doUpdate = false
        end
        
        if (doUpdate) then
            self:requireUpdate()
        end
    end )
end

function TextBox:update()
    local w = self:getWidth()
    local h = self:getHeight()

    self:base():resetBuffer(w, h)

    local text = self:getUsedText()
    local length = #text
    local align = self:getAlign()
    local offset = 0

    if (align == TextBox.Align.Center) then
        offset = math.floor((w / 2) -(length / 2))
    elseif (align == TextBox.Align.Right) then
        offset = w - length
        if (offset < 0) then
            offset = 0
        end
    end

    for i = 1, #text do
        self:base():write(i + offset, 1, text:sub(i, i))
    end
end

function TextBox:getMinWidth()
    return #self:getUsedText()
end

function TextBox:getMinHeight()
    return 1
end

function TextBox:getText()
    return self._text
end

function TextBox:setText(text)
    self._text = text
end

function TextBox:getDefaultText()
    return self._defaultText
end

function TextBox:getUsedText()
    if (#self._text == 0) then
        return self:getDefaultText()
    end

    return self._text
end

function TextBox:setAlign(align)
    self._align = align
end

function TextBox:getAlign()
    return self._align
end

TextBox.Align = {
    Left = 0,
    Center = 1,
    Right = 2
}

if (UI == nil) then UI = { } end
UI.TextBox = TextBox