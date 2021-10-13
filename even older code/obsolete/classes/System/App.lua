local App = { }

--- <summary></summary>
--- <returns type="UI.App"></returns>
function App.new(window)
    local instance = { }
    setmetatable(instance, { __index = App })

    instance:ctor(window)

    return instance
end

function App:ctor(window)
    self._window = window
end

--- <summary></summary>
--- <returns type="UI.AppWindow"></returns>
function App:getWindow()
    return self._window
end

function App:run()
end

function App:quit()
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function App.cast(instance)
    return instance
end

if (System == nil) then System = { } end
System.App = App