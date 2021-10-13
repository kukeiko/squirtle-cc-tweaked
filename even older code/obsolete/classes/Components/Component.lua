local Component = { }

--- <summary>
--- </summary>
--- <returns type="Components.Component"></returns>
function Component.new(computer, name, dependencies)
    local instance = { }
    setmetatable(instance, { __index = Component })
    instance:ctor(computer, name, dependencies)

    return instance
end

function Component:ctor(computer, name, dependencies)
    dependencies = dependencies or { }

    self._computer = computer
    self._name = name
    self._dependencies = dependencies
end

function Component:getName()
    return self._name
end

function Component:load()
    self:loadDependencies()
end

function Component:saveTable(name, t)
    Disk.saveTable(Disk.combine("data", self:getName(), name), t)
end

function Component:loadTable(name)
    return Disk.loadTable(Disk.combine("data", self:getName(), name))
end

function Component:tableExists(name)
    return Disk.exists(Disk.combine("data", self:getName(), name))
end

function Component:addDependency(name)
    table.insert(self._dependencies, name)
end

function Component:loadDependencies()
    for k, name in pairs(self._dependencies) do
        self:getComputer():loadComponent(name)
    end
end

--- <summary>
--- name: (string)
--- </summary>
--- <returns type="Components.Component"></returns>
function Component:getDependency(name)
    return self:getComputer():getComponent(name)
end

--- <summary>
--- </summary>
--- <returns type="System.Computer"></returns>
function Component:getComputer()
    return self._computer
end

--- <summary>component: (Component)</summary>
--- <returns type="Components.Component"></returns>
function Component.cast(component)
    return component
end

if (Components == nil) then Components = { } end
Components.Component = Component