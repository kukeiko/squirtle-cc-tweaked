local HLine = { }


--- <summary></summary>
--- <returns type="Kevlar.HLine"></returns>
HLine.new = function(text, buffer)
    local instance = { }
    setmetatable(instance, { __index = HLine })
    text = text or "-"
    instance:ctor(text, buffer)
    instance:draw()
    
    return instance
end

function HLine:ctor (text, buffer)
    self._buffer = Kevlar.IBuffer.as(buffer)
    self._text = text
end

--- <summary></summary>
--- <returns type="Kevlar.HLine"></returns>
HLine.cast = function (instance) return instance end

function HLine:draw()
    local i = 1
    
    for x = 1, self._buffer:getWidth() do
        self._buffer:write(x, 1, self._text:sub(i, i))
        i =((i + 1) % #self._text) + 1
    end
end

if (Kevlar == nil) then Kevlar = { } end
Kevlar.HLine = HLine