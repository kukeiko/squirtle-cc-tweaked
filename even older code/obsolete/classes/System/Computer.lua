local Computer = { }

--- <summary>
--- </summary>
--- <returns type="Computer"></returns>
function Computer.new()
    local instance = { }
    setmetatable(instance, { __index = Computer })
    instance:ctor()

    return instance
end

function Computer:ctor()
    self._components = { }
    self._loadedComponents = { }
end

--- <summary>
--- name: (string)
--- </summary>
--- <returns type="Components.Component"></returns>
function Computer:getOrConstructComponent(name)
    if (self._components[name] == nil) then
        local componentType = Utils.crawl(Components, string.split(name, "."))
        local component = componentType.new(self)

        self._components[name] = component
    end

    return self._components[name]
end

--- <summary>
--- name: (string)
--- </summary>
--- <returns type="Components.Component"></returns>
function Computer:loadComponent(name)
    local component = self:getOrConstructComponent(name)

    if (not self._loadedComponents[name]) then
        component:load()
        self._loadedComponents[name] = true
    end

    return component
end

--- <summary>
--- name: (string)
--- </summary>
--- <returns type="Components.Component"></returns>
function Computer:getComponent(name)
    return self._components[name]
end

function Computer:getDeviceId()
    return os.getComputerID()
end

function Computer:isComputer()
    return not self:isTurtle() and not self:isPocket()
end

function Computer:isTurtle()
    return turtle ~= nil
end

function Computer:isPocket()
    return pocket ~= nil
end

--- <summary>
--- computer: (Computer)
--- </summary>
--- <returns type="System.Computer"></returns>
function Computer.cast(computer)
    return computer
end

if (System == nil) then System = { } end
System.Computer = Computer