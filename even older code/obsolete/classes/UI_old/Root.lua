local Root = { }

--- <summary></summary>
--- <returns type="UI.Root"></returns>
function Root.init()
    setmetatable(Root, { __index = UI.Node })
    Root:ctor()

    return Root
end

function Root:ctor()
    local w, h = term.getSize()
    self._window = window.create(term.current(), 1, 1, w, h)
    self._children = { }
    self._isVisible = true
    self._scroll = 0
end

--- <summary></summary>
--- <returns type="UI.Node"></returns>
function Root:base()
    return self
end

--if (UI == nil) then UI = { } end
--UI.Root = Root