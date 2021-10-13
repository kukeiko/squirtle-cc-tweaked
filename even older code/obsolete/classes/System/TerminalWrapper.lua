TerminalWrapper = { }

--- <summary></summary>
--- <returns type="TerminalWrapper"></returns>
function TerminalWrapper.new(term)
    local instance = UI.Node.new()
    setmetatable(TerminalWrapper, { __index = UI.Node })
    setmetatable(instance, { __index = TerminalWrapper })
    instance:ctor(term)

    return instance
end

function TerminalWrapper:ctor(term)
    self._terminal = term
    self._node = nil
end

--- <summary></summary>
--- <returns type="TerminalWrapper"></returns>
function TerminalWrapper.cast(instance)
    return instance
end

function TerminalWrapper:requireUpdate()
    self:update()
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function TerminalWrapper:getNode()
    return self._node
end

function TerminalWrapper:setNode(node)
    self._node = node
    node:setParent(self)
end

function TerminalWrapper:update()
    local term = self._terminal
    local node = self:getNode()

    if (node == nil) then return nil end

    local w, h = term.getSize()

    node:setSize(w, h)
    node:update()

    local buffer = node:getBuffer()

    term.clear()
    term.setCursorPos(1, 1)

    for y = 1, h do
        if (buffer[y] == nil) then
            break
        end

        for x = 1, w do
            if (buffer[y][x] == nil) then
                break
            end

            term.setCursorPos(x, y)
            term.write(buffer[y][x])
        end
    end
end

if (System == nil) then System = { } end
System.TerminalWrapper = TerminalWrapper