local Label = { }

--- <summary></summary>
--- <returns type="UI.Label"></returns>
function Label.new(text, align)
    local instance = UI.Leaf.new()
    setmetatable(Label, { __index = UI.Leaf })
    setmetatable(instance, { __index = Label })

    text = text or ""
    align = align or Label.Align.Left

    instance:ctor(text, align)

    return instance
end

function Label:ctor(text, align)
    self._text = text
    self._align = align
end

function Label:update()
    local w = self:getWidth()
    local h = self:getHeight()

    self:base():resetBuffer(w, h)

    local lines = self:getWordLines()
    local align = self:getAlign()

    for i = 1, #lines do
        local line = lines[i]
        local lineText = table.concat(line, " ")
        local offset = 0

        if (align == Label.Align.Center) then
            offset = math.floor((w / 2) -(#lineText / 2))
        elseif (align == Label.Align.Right) then
            offset = w - #lineText
            if (offset < 0) then
                offset = 0
            end
        elseif (align == Label.Align.Justify and #line > 1 and i < #lines) then
            local lineWordsLength = #lineText -(#line - 1)
            local remainingSpace = w - lineWordsLength
            local numSpacesEach = math.floor(remainingSpace /(#line - 1))
            local leftOver = remainingSpace %(#line - 1)

            if (leftOver == 0) then
                lineText = table.concat(line, string.rep(" ", numSpacesEach))
            else
                lineText = ""

                for e = 1, #line do
                    if (e == #line) then
                        lineText = lineText .. line[e]
                    elseif (e <= leftOver) then
                        lineText = lineText .. line[e] .. string.rep(" ", numSpacesEach + 1)
                    else
                        lineText = lineText .. line[e] .. string.rep(" ", numSpacesEach)
                    end
                end
            end
        end

        for e = 1, #lineText do
            self:base():write(e + offset, i, lineText:sub(e, e))
        end
    end
end

function Label:getContentWidth()
    return #self:getText()
    --    local lines = self:getWordLines()
    --    local highestWidth = nil

    --    for i = 1, #lines do
    --        local line = lines[i]
    --        local lineLength = #table.concat(line, " ")

    --        if (highestWidth == nil or lineLength > highestWidth) then
    --            highestWidth = lineLength
    --        end
    --    end

    --    return highestWidth
end

function Label:getContentHeight()
    return #self:getWordLines()
end

function Label:getText()
    return self._text
end

function Label:setText(text)
    self._text = text
end
--- <summary>Returns the text as single words</summary>
function Label:getWords()
    return self:getText():split(" ")
end

--- <summary>Returns the current number of words</summary>
function Label:numWords()
    return #self:getWords()
end

function Label:getWordLines()
    local w = self:getWidth()
    local words = self:getWords()
    local lines = { }
    local currentLine = { }
    local currentLineLength = 0

    lines[#lines + 1] = currentLine

    for i = 1, #words do
        local word = words[i]

        if (#currentLine == 0) then
            currentLine[#currentLine + 1] = word
            currentLineLength = currentLineLength + #word
        elseif (currentLineLength + #word + 1 <= w) then
            currentLine[#currentLine + 1] = word
            currentLineLength = currentLineLength + #word + 1
        else
            currentLine = { }
            lines[#lines + 1] = currentLine
            currentLine[#currentLine + 1] = word
            currentLineLength = #word
        end
    end

    return lines
end

function Label:setAlign(align)
    self._align = align
end

function Label:getAlign()
    return self._align
end

Label.Align = {
    Left = 0,
    Center = 1,
    Right = 2,
    Justify = 3
}

--- <summary></summary>
--- <returns type="UI.Label"></returns>
function Label.cast(Label)
    return Label
end

--- <summary></summary>
--- <returns type="UI.Leaf"></returns>
function Label:base()
    return self
end

if (UI == nil) then UI = { } end
UI.Label = Label